//+------------------------------------------------------------------+
//|                                      VWAP_Revolutionary_MA72.mq4 |
//|                        Copyright 2025, Revolutionary VWAP System |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Revolutionary VWAP System"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Lignes principales
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "MA 72"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Bandes VWAP
#property indicator_label3  "VWAP Upper"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "VWAP Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Signaux
#property indicator_label5  "Signal Achat"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrLime
#property indicator_width5  3

//--- Paramètres d'entrée
input int MA_Period = 72;                    // Période MA
input ENUM_MA_METHOD MA_Method = MODE_SMA;   // Méthode MA
input double Wick_Test_Distance = 10;        // Distance max pour test mèche (en points)
input double Rejection_MinSize = 20;         // Taille min de la mèche (en points)
input double VWAP_StdDev = 2.0;              // Écart-type pour bandes VWAP
input bool Show_Alerts = true;               // Afficher alertes sonores
input bool Show_Panel = true;                // Afficher panel d'information
input color Panel_Color = clrDarkSlateGray;  // Couleur du panel

//--- Buffers
double VWAPBuffer[];
double MA72Buffer[];
double VWAPUpperBuffer[];
double VWAPLowerBuffer[];
double SignalBuffer[];

//--- Variables globales
datetime lastAlertTime = 0;
double sessionVolume = 0;
double sessionTypicalPriceVolume = 0;
double sessionTypicalPriceSquaredVolume = 0;
datetime sessionStartTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Assignation des buffers
   SetIndexBuffer(0, VWAPBuffer);
   SetIndexBuffer(1, MA72Buffer);
   SetIndexBuffer(2, VWAPUpperBuffer);
   SetIndexBuffer(3, VWAPLowerBuffer);
   SetIndexBuffer(4, SignalBuffer);

   //--- Configuration des signaux
   SetIndexArrow(4, 233); // Flèche vers le haut
   SetIndexEmptyValue(4, 0);

   //--- Étiquettes
   IndicatorShortName("VWAP Revolutionary + MA72");
   SetIndexLabel(0, "VWAP");
   SetIndexLabel(1, "MA 72");
   SetIndexLabel(2, "VWAP +2SD");
   SetIndexLabel(3, "VWAP -2SD");
   SetIndexLabel(4, "Signal Achat");

   //--- Initialisation
   sessionStartTime = 0;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int limit;

   //--- Déterminer à partir de quelle barre calculer
   if(prev_calculated == 0)
   {
      limit = rates_total - 1;
      ArrayInitialize(VWAPBuffer, EMPTY_VALUE);
      ArrayInitialize(MA72Buffer, EMPTY_VALUE);
      ArrayInitialize(VWAPUpperBuffer, EMPTY_VALUE);
      ArrayInitialize(VWAPLowerBuffer, EMPTY_VALUE);
      ArrayInitialize(SignalBuffer, 0);
   }
   else
   {
      limit = rates_total - prev_calculated;
   }

   //--- Calculer la MA 72 pour toutes les barres
   for(int i = limit; i >= 0; i--)
   {
      if(i < rates_total - MA_Period)
      {
         double sum = 0;
         for(int j = 0; j < MA_Period; j++)
         {
            sum += close[i + j];
         }
         MA72Buffer[i] = sum / MA_Period;
      }
      else
      {
         MA72Buffer[i] = close[i];
      }
   }

   //--- Calculer le VWAP
   CalculateVWAP(rates_total, time, high, low, close, tick_volume, volume);

   //--- Détecter les signaux sur les 3 dernières bougies fermées
   for(int i = MathMin(3, rates_total - 2); i >= 1; i--)
   {
      SignalBuffer[i] = 0;

      if(MA72Buffer[i] == EMPTY_VALUE || MA72Buffer[i] == 0)
         continue;

      //--- Détecter éjection/rebond sur MA72
      if(DetectMA72Signal(i, open, high, low, close))
      {
         SignalBuffer[i] = low[i] - (10 * Point);

         //--- Alerte sonore (seulement pour la barre actuelle)
         if(i == 1 && Show_Alerts && time[1] != lastAlertTime)
         {
            Alert("🚀 SIGNAL ACHAT VWAP Revolutionary sur ", Symbol(), " ", Period(), "min - Prix: ", close[1]);
            PlaySound("alert2.wav");
            lastAlertTime = time[1];
         }
      }
   }

   //--- Afficher le panel d'information
   if(Show_Panel)
   {
      DisplayInfoPanel();
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calcul du VWAP avec bandes                                       |
//+------------------------------------------------------------------+
void CalculateVWAP(const int rates_total,
                   const datetime &time[],
                   const double &high[],
                   const double &low[],
                   const double &close[],
                   const long &tick_volume[],
                   const long &volume[])
{
   //--- Reset VWAP à chaque nouvelle session (nouveau jour)
   datetime currentDay = 0;
   double cumVolume = 0;
   double cumTypicalPriceVolume = 0;
   double cumTypicalPriceSquaredVolume = 0;

   for(int i = rates_total - 1; i >= 0; i--)
   {
      datetime barDay = StringToTime(TimeToString(time[i], TIME_DATE));

      //--- Nouveau jour = reset
      if(barDay != currentDay)
      {
         currentDay = barDay;
         cumVolume = 0;
         cumTypicalPriceVolume = 0;
         cumTypicalPriceSquaredVolume = 0;
      }

      //--- Calcul du typical price
      double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;

      //--- Volume (utiliser tick_volume si volume réel non disponible)
      double vol = (volume[i] > 0) ? volume[i] : tick_volume[i];

      //--- Cumuls
      cumVolume += vol;
      cumTypicalPriceVolume += (typicalPrice * vol);
      cumTypicalPriceSquaredVolume += (typicalPrice * typicalPrice * vol);

      //--- VWAP
      if(cumVolume > 0)
      {
         VWAPBuffer[i] = cumTypicalPriceVolume / cumVolume;

         //--- Écart-type
         double variance = (cumTypicalPriceSquaredVolume / cumVolume) - (VWAPBuffer[i] * VWAPBuffer[i]);
         double stdDev = (variance > 0) ? MathSqrt(variance) : 0;

         //--- Bandes
         VWAPUpperBuffer[i] = VWAPBuffer[i] + (VWAP_StdDev * stdDev);
         VWAPLowerBuffer[i] = VWAPBuffer[i] - (VWAP_StdDev * stdDev);
      }
      else
      {
         VWAPBuffer[i] = close[i];
         VWAPUpperBuffer[i] = close[i];
         VWAPLowerBuffer[i] = close[i];
      }
   }
}

//+------------------------------------------------------------------+
//| Détection signal éjection/rebond sur MA72                        |
//+------------------------------------------------------------------+
bool DetectMA72Signal(int index,
                      const double &open[],
                      const double &high[],
                      const double &low[],
                      const double &close[])
{
   double ma72 = MA72Buffer[index];

   if(ma72 == EMPTY_VALUE || ma72 == 0)
      return false;

   //--- La mèche doit tester la MA72
   double distanceToMA = MathAbs(low[index] - ma72) / Point;

   //--- Conditions pour un signal valide:
   //--- 1. La mèche basse teste la MA72 (distance < seuil)
   //--- 2. La bougie clôture AU-DESSUS de la MA72 (rejet/éjection)
   //--- 3. La mèche doit être significative

   bool wickTestsMA = (distanceToMA <= Wick_Test_Distance);
   bool closesAboveMA = (close[index] > ma72);

   //--- Taille de la mèche basse
   double wickSize = (close[index] > open[index]) ?
                     (MathMin(open[index], close[index]) - low[index]) :
                     (MathMin(open[index], close[index]) - low[index]);

   wickSize = wickSize / Point;

   bool significantWick = (wickSize >= Rejection_MinSize);

   //--- Bougie haussière après le test
   bool bullishCandle = (close[index] >= open[index]);

   //--- Conditions additionnelles pour améliorer la qualité du signal
   //--- Le corps de la bougie doit être au-dessus de MA72
   double bodyBottom = MathMin(open[index], close[index]);
   bool bodyAboveMA = (bodyBottom >= ma72 * 0.9995); // Petite tolérance

   //--- VWAP comme filtre additionnel (optionnel mais recommandé)
   bool aboveVWAP = (close[index] > VWAPBuffer[index]);

   //--- Signal valide si toutes les conditions sont réunies
   if(wickTestsMA && closesAboveMA && significantWick && bullishCandle)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Affichage du panel d'information                                 |
//+------------------------------------------------------------------+
void DisplayInfoPanel()
{
   string panelName = "VWAP_Revolutionary_Panel";
   int x = 20;
   int y = 30;
   int width = 280;
   int height = 160;

   //--- Rectangle de fond
   if(ObjectFind(0, panelName) < 0)
   {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, Panel_Color);
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, true);
   }

   //--- Titre
   CreateLabel("VWAP_Title", "🚀 VWAP REVOLUTIONARY", x + 10, y + 8, clrWhite, 10, "Arial Black");

   //--- Informations actuelles
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double vwap = VWAPBuffer[1];
   double ma72 = MA72Buffer[1];

   string priceVsVWAP = (currentPrice > vwap) ? "Au-dessus ✓" : "En-dessous ✗";
   color colorVWAP = (currentPrice > vwap) ? clrLime : clrRed;

   string priceVsMA72 = (currentPrice > ma72) ? "Au-dessus ✓" : "En-dessous ✗";
   color colorMA72 = (currentPrice > ma72) ? clrLime : clrRed;

   CreateLabel("VWAP_Price", "Prix actuel: " + DoubleToString(currentPrice, Digits), x + 10, y + 30, clrWhite, 8);
   CreateLabel("VWAP_Value", "VWAP: " + DoubleToString(vwap, Digits), x + 10, y + 50, clrDodgerBlue, 8);
   CreateLabel("VWAP_Status", priceVsVWAP, x + 150, y + 50, colorVWAP, 8);

   CreateLabel("MA72_Value", "MA 72: " + DoubleToString(ma72, Digits), x + 10, y + 70, clrOrange, 8);
   CreateLabel("MA72_Status", priceVsMA72, x + 150, y + 70, colorMA72, 8);

   //--- Distance à la MA72
   double distanceToMA = MathAbs(currentPrice - ma72) / Point;
   CreateLabel("Distance_MA72", "Distance MA72: " + DoubleToString(distanceToMA, 1) + " pts", x + 10, y + 90, clrYellow, 8);

   //--- Guide pour débutants
   CreateLabel("Guide_Title", "📊 Signal Achat quand:", x + 10, y + 115, clrYellow, 8, "Arial Bold");
   CreateLabel("Guide_1", "✓ Mèche teste MA 72", x + 10, y + 133, clrWhite, 7);
   CreateLabel("Guide_2", "✓ Clôture au-dessus MA 72", x + 10, y + 146, clrWhite, 7);
}

//+------------------------------------------------------------------+
//| Créer un label texte                                             |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize = 8, string font = "Arial")
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Nettoyage à la désactivation                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Supprimer tous les objets créés
   ObjectsDeleteAll(0, "VWAP_");
   Comment("");
}
//+------------------------------------------------------------------+

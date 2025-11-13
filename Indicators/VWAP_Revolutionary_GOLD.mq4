//+------------------------------------------------------------------+
//|                                       VWAP_Revolutionary_GOLD.mq4|
//|                        Copyright 2025, Revolutionary VWAP System |
//|                    Optimisé pour XAUUSD (OR) - M5 à H1           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Revolutionary VWAP System"
#property link      ""
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Lignes principales
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "MA 72"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Bandes VWAP
#property indicator_label3  "VWAP Upper"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "VWAP Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGold
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Signaux
#property indicator_label5  "Signal Achat"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrLime
#property indicator_width5  4

//--- Paramètres d'entrée
input int MA_Period = 72;                     // Période MA (72 optimale pour l'or)
input ENUM_MA_METHOD MA_Method = MODE_EMA;    // Méthode MA (EMA recommandée pour l'or)
input bool Auto_Optimize = true;              // Optimisation auto pour XAUUSD
input double Wick_Test_Distance = 80;         // Distance max test mèche (points - Gold optimized)
input double Rejection_MinSize = 150;         // Taille min mèche (points - Gold optimized)
input int ATR_Period = 14;                    // Période ATR pour filtre volatilité
input double ATR_Multiplier = 1.5;            // Multiplicateur ATR pour signaux
input double VWAP_StdDev = 2.0;               // Écart-type pour bandes VWAP
input double Min_RiskReward = 1.5;            // Ratio risque/récompense minimum
input bool Use_ATR_Filter = true;             // Utiliser filtre ATR
input bool Use_Trend_Filter = true;           // Utiliser filtre de tendance
input bool Show_Alerts = true;                // Afficher alertes sonores
input bool Show_Panel = true;                 // Afficher panel d'information
input color Panel_Color = clrDarkGoldenrod;   // Couleur du panel

//--- Buffers
double VWAPBuffer[];
double MA72Buffer[];
double VWAPUpperBuffer[];
double VWAPLowerBuffer[];
double SignalBuffer[];

//--- Variables globales
datetime lastAlertTime = 0;
double pointMultiplier = 1.0;
bool isGoldSymbol = false;
string optimizedSymbol = "";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Détecter si c'est de l'or
   string symbol = Symbol();
   isGoldSymbol = (StringFind(symbol, "XAU") >= 0 ||
                   StringFind(symbol, "GOLD") >= 0 ||
                   StringFind(symbol, "gold") >= 0);

   optimizedSymbol = symbol;

   //--- Ajuster le multiplicateur de points pour l'or
   if(isGoldSymbol)
   {
      pointMultiplier = 10.0; // L'or utilise généralement 10 points = 0.10$
   }
   else
   {
      pointMultiplier = 1.0;
   }

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
   string timeframeStr = GetTimeframeString();
   IndicatorShortName("VWAP Gold Revolutionary [" + timeframeStr + "]");
   SetIndexLabel(0, "VWAP Gold");
   SetIndexLabel(1, "MA 72 EMA");
   SetIndexLabel(2, "VWAP +2SD");
   SetIndexLabel(3, "VWAP -2SD");
   SetIndexLabel(4, "Signal Achat Gold");

   //--- Message d'information
   if(isGoldSymbol && Auto_Optimize)
   {
      Print("✅ VWAP Revolutionary optimisé pour ", symbol, " sur timeframe ", timeframeStr);
      Print("📊 Paramètres: Wick=", Wick_Test_Distance, "pts, MinWick=", Rejection_MinSize, "pts, ATR Filter=", Use_ATR_Filter);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Obtenir le nom du timeframe                                      |
//+------------------------------------------------------------------+
string GetTimeframeString()
{
   switch(Period())
   {
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return IntegerToString(Period());
   }
}

//+------------------------------------------------------------------+
//| Obtenir les paramètres optimisés selon le timeframe              |
//+------------------------------------------------------------------+
void GetOptimizedParameters(double &wickDist, double &minWick, double &atrMult)
{
   if(!Auto_Optimize || !isGoldSymbol)
   {
      wickDist = Wick_Test_Distance;
      minWick = Rejection_MinSize;
      atrMult = ATR_Multiplier;
      return;
   }

   //--- Paramètres optimisés pour l'or selon le timeframe
   switch(Period())
   {
      case PERIOD_M5:
         wickDist = 50;    // M5: Plus sensible, 50 pts = 0.50$
         minWick = 100;    // Mèche min 100 pts = 1.00$
         atrMult = 1.2;    // ATR plus strict
         break;

      case PERIOD_M15:
         wickDist = 80;    // M15: 80 pts = 0.80$
         minWick = 150;    // Mèche min 150 pts = 1.50$
         atrMult = 1.5;
         break;

      case PERIOD_M30:
         wickDist = 100;   // M30: 100 pts = 1.00$
         minWick = 200;    // Mèche min 200 pts = 2.00$
         atrMult = 1.5;
         break;

      case PERIOD_H1:
         wickDist = 150;   // H1: 150 pts = 1.50$
         minWick = 300;    // Mèche min 300 pts = 3.00$
         atrMult = 2.0;
         break;

      default:
         wickDist = Wick_Test_Distance;
         minWick = Rejection_MinSize;
         atrMult = ATR_Multiplier;
   }
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

   //--- Calculer la MA 72 (EMA pour meilleure réactivité sur l'or)
   CalculateMA(rates_total, limit, close);

   //--- Calculer le VWAP
   CalculateVWAP(rates_total, time, high, low, close, tick_volume, volume);

   //--- Détecter les signaux sur les 3 dernières bougies fermées
   for(int i = MathMin(3, rates_total - 2); i >= 1; i--)
   {
      SignalBuffer[i] = 0;

      if(MA72Buffer[i] == EMPTY_VALUE || MA72Buffer[i] == 0)
         continue;

      //--- Détecter éjection/rebond sur MA72 avec filtres avancés
      if(DetectGoldSignal(i, rates_total, open, high, low, close))
      {
         SignalBuffer[i] = low[i] - (20 * Point * pointMultiplier);

         //--- Alerte sonore (seulement pour la barre actuelle)
         if(i == 1 && Show_Alerts && time[1] != lastAlertTime)
         {
            double entryPrice = close[1];
            double sl = CalculateStopLoss(1, low);
            double tp = CalculateTargetPrice(1, entryPrice, sl);
            double rr = (tp - entryPrice) / (entryPrice - sl);

            Alert("🚀💰 SIGNAL OR VWAP Revolutionary sur ", Symbol(), " ", GetTimeframeString(),
                  " - Prix: ", DoubleToString(entryPrice, Digits),
                  " | SL: ", DoubleToString(sl, Digits),
                  " | TP: ", DoubleToString(tp, Digits),
                  " | R:R = 1:", DoubleToString(rr, 1));
            PlaySound("alert2.wav");
            lastAlertTime = time[1];
         }
      }
   }

   //--- Afficher le panel d'information
   if(Show_Panel)
   {
      DisplayGoldPanel();
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calcul de la MA (EMA ou SMA selon paramètre)                     |
//+------------------------------------------------------------------+
void CalculateMA(const int rates_total, const int limit, const double &close[])
{
   if(MA_Method == MODE_EMA)
   {
      //--- Calcul EMA
      double alpha = 2.0 / (MA_Period + 1.0);

      for(int i = limit; i >= 0; i--)
      {
         if(i == rates_total - 1)
         {
            MA72Buffer[i] = close[i];
         }
         else if(i == rates_total - 2)
         {
            double sum = 0;
            int count = MathMin(MA_Period, rates_total - 1);
            for(int j = 0; j < count; j++)
            {
               sum += close[i + j];
            }
            MA72Buffer[i] = sum / count;
         }
         else
         {
            MA72Buffer[i] = (close[i] * alpha) + (MA72Buffer[i + 1] * (1 - alpha));
         }
      }
   }
   else
   {
      //--- Calcul SMA standard
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
   }
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
//| Calcul de l'ATR                                                   |
//+------------------------------------------------------------------+
double CalculateATR(int index, const double &high[], const double &low[], const double &close[])
{
   double atr = 0;

   for(int i = 0; i < ATR_Period; i++)
   {
      int idx = index + i;
      double tr;

      if(idx == 0)
      {
         tr = high[idx] - low[idx];
      }
      else
      {
         double hl = high[idx] - low[idx];
         double hc = MathAbs(high[idx] - close[idx + 1]);
         double lc = MathAbs(low[idx] - close[idx + 1]);
         tr = MathMax(hl, MathMax(hc, lc));
      }

      atr += tr;
   }

   return atr / ATR_Period;
}

//+------------------------------------------------------------------+
//| Détection signal optimisé pour l'or                              |
//+------------------------------------------------------------------+
bool DetectGoldSignal(int index,
                      const int rates_total,
                      const double &open[],
                      const double &high[],
                      const double &low[],
                      const double &close[])
{
   double ma72 = MA72Buffer[index];

   if(ma72 == EMPTY_VALUE || ma72 == 0)
      return false;

   //--- Obtenir les paramètres optimisés selon le timeframe
   double optimWickDist, optimMinWick, optimATRMult;
   GetOptimizedParameters(optimWickDist, optimMinWick, optimATRMult);

   //--- La mèche doit tester la MA72
   double distanceToMA = MathAbs(low[index] - ma72) / Point;

   //--- Conditions de base
   bool wickTestsMA = (distanceToMA <= optimWickDist * pointMultiplier);
   bool closesAboveMA = (close[index] > ma72);

   //--- Taille de la mèche basse
   double bodyBottom = MathMin(open[index], close[index]);
   double wickSize = (bodyBottom - low[index]) / Point;

   bool significantWick = (wickSize >= optimMinWick * pointMultiplier);

   //--- Bougie haussière
   bool bullishCandle = (close[index] >= open[index]);

   //--- Le corps doit être au-dessus de MA72
   bool bodyAboveMA = (bodyBottom >= ma72 * 0.999); // Tolérance ajustée pour l'or

   //--- VWAP comme filtre principal
   bool aboveVWAP = (close[index] > VWAPBuffer[index]);

   //--- FILTRE ATR (volatilité suffisante)
   bool atrOk = true;
   if(Use_ATR_Filter && index < rates_total - ATR_Period - 1)
   {
      double atr = CalculateATR(index, high, low, close);
      double wickInPrice = wickSize * Point;
      atrOk = (wickInPrice >= atr * optimATRMult * 0.5); // La mèche doit être significative par rapport à l'ATR
   }

   //--- FILTRE DE TENDANCE (prix au-dessus de VWAP et MA72)
   bool trendOk = true;
   if(Use_Trend_Filter)
   {
      // Prix au-dessus du VWAP = tendance haussière
      // MA72 en pente haussière
      bool vwapTrend = (close[index] > VWAPBuffer[index]);
      bool maTrend = (index < rates_total - 3) ? (MA72Buffer[index] > MA72Buffer[index + 2]) : true;
      trendOk = vwapTrend && maTrend;
   }

   //--- FILTRE RISQUE/RECOMPENSE
   bool rrOk = true;
   if(Min_RiskReward > 0)
   {
      double entryPrice = close[index];
      double sl = CalculateStopLoss(index, low);
      double tp = VWAPUpperBuffer[index]; // Target = bande supérieure VWAP

      if(sl > 0 && tp > entryPrice)
      {
         double risk = entryPrice - sl;
         double reward = tp - entryPrice;
         double rr = reward / risk;
         rrOk = (rr >= Min_RiskReward);
      }
   }

   //--- Force de la bougie (ratio corps/mèche)
   double bodySize = MathAbs(close[index] - open[index]);
   double totalSize = high[index] - low[index];
   bool strongRejection = (totalSize > 0) && (wickSize / totalSize >= 0.4); // Mèche = au moins 40% de la bougie

   //--- Signal valide si TOUTES les conditions sont réunies
   if(wickTestsMA && closesAboveMA && significantWick && bullishCandle &&
      bodyAboveMA && aboveVWAP && atrOk && trendOk && rrOk && strongRejection)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calcul du Stop Loss optimisé                                     |
//+------------------------------------------------------------------+
double CalculateStopLoss(int index, const double &low[])
{
   // SL sous le plus bas de la bougie de signal
   double sl = low[index];

   // Ajouter un buffer de sécurité (0.50$ pour l'or)
   double buffer = 50 * Point * pointMultiplier;
   sl = sl - buffer;

   return sl;
}

//+------------------------------------------------------------------+
//| Calcul du Take Profit optimisé                                   |
//+------------------------------------------------------------------+
double CalculateTargetPrice(int index, double entry, double sl)
{
   // Option 1: Bande supérieure VWAP
   double tp1 = VWAPUpperBuffer[index];

   // Option 2: Ratio risque/récompense
   double risk = entry - sl;
   double tp2 = entry + (risk * Min_RiskReward);

   // Prendre le plus proche pour être conservateur
   return MathMin(tp1, tp2);
}

//+------------------------------------------------------------------+
//| Affichage du panel optimisé pour l'or                            |
//+------------------------------------------------------------------+
void DisplayGoldPanel()
{
   string panelName = "VWAP_Gold_Panel";
   int x = 20;
   int y = 30;
   int width = 320;
   int height = 200;

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
   CreateLabel("VWAP_Title", "💰 VWAP GOLD REVOLUTIONARY", x + 10, y + 8, clrYellow, 11, "Arial Black");
   CreateLabel("VWAP_Symbol", Symbol() + " | " + GetTimeframeString(), x + 10, y + 26, clrWhite, 8, "Arial Bold");

   //--- Informations actuelles
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double vwap = VWAPBuffer[1];
   double ma72 = MA72Buffer[1];

   string priceVsVWAP = (currentPrice > vwap) ? "Haussier ✓" : "Baissier ✗";
   color colorVWAP = (currentPrice > vwap) ? clrLime : clrRed;

   string priceVsMA72 = (currentPrice > ma72) ? "Au-dessus ✓" : "En-dessous ✗";
   color colorMA72 = (currentPrice > ma72) ? clrLime : clrRed;

   CreateLabel("VWAP_Price", "Prix: $" + DoubleToString(currentPrice, Digits), x + 10, y + 48, clrWhite, 9, "Arial Bold");
   CreateLabel("VWAP_Value", "VWAP: $" + DoubleToString(vwap, Digits), x + 10, y + 68, clrGold, 8);
   CreateLabel("VWAP_Status", priceVsVWAP, x + 200, y + 68, colorVWAP, 8, "Arial Bold");

   CreateLabel("MA72_Value", "MA72: $" + DoubleToString(ma72, Digits), x + 10, y + 86, clrOrangeRed, 8);
   CreateLabel("MA72_Status", priceVsMA72, x + 200, y + 86, colorMA72, 8, "Arial Bold");

   //--- Distance à la MA72 (en dollars pour l'or)
   double distanceToMA = MathAbs(currentPrice - ma72);
   CreateLabel("Distance_MA72", "Distance MA72: $" + DoubleToString(distanceToMA, 2), x + 10, y + 104, clrYellow, 8);

   //--- Potentiel de trade
   if(currentPrice > ma72)
   {
      double potentialTP = VWAPUpperBuffer[1];
      double potentialGain = potentialTP - currentPrice;
      CreateLabel("Potential_TP", "Potentiel TP: $" + DoubleToString(potentialGain, 2), x + 10, y + 122, clrLime, 8);
   }
   else
   {
      CreateLabel("Potential_TP", "Attendre signal...", x + 10, y + 122, clrOrange, 8);
   }

   //--- Paramètres actifs
   double optWick, optMin, optATR;
   GetOptimizedParameters(optWick, optMin, optATR);
   string paramInfo = "Params: Wick=" + DoubleToString(optWick, 0) + " | MinWick=" + DoubleToString(optMin, 0);
   CreateLabel("Params_Info", paramInfo, x + 10, y + 140, clrSilver, 7);

   //--- Guide simplifié
   CreateLabel("Guide_Title", "📊 Signal ACHAT quand:", x + 10, y + 160, clrYellow, 8, "Arial Bold");
   CreateLabel("Guide_1", "✓ Mèche teste MA72", x + 10, y + 176, clrWhite, 7);
   CreateLabel("Guide_2", "✓ Clôture > MA72 + VWAP", x + 10, y + 189, clrWhite, 7);
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

//+------------------------------------------------------------------+
//|                                                         MACD.mq5 |
//|                   Copyright 2009-2020, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2022-2022, lumtu Software"
#property link        "http://www.lumtu.de"
#property description "iZigZag"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
//--- plot ZigZag
#property indicator_label1  "iZigZag"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_DASHDOT
#property indicator_width1  1

#property indicator_label2  "iPSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDarkGray
#property indicator_width2  5

#include "iLine.mqh"

input int InpLength      = 10; // Length minval=0, step=5)
input int InpErrorPercent= 10; // ErrorPercent minval=5, step=5, maxval=20)
input int InpMaxRiskPerReward = 40; // Max Risk Per Reward (Double Top/Bottom) minval=0, step=10

input bool InpShowDoublePattern = false; // Show Double Pattern


double PatternSignal[]; // main buffer
double ZigZagBuffer[]; // main buffer

int ZigZagIdx[]; // index buffer of zigzag points
int ZigZagDir[];
double ZigZagRatios[];
int lastDirction = 0;
int DeviationThreshold = 0;

double err_min = (100.0 - InpErrorPercent) / 100.0;
double err_max = (100.0 + InpErrorPercent) / 100.0;

uint bullishColor = clrSteelBlue;
uint bearishColor = clrDarkMagenta;

iLine DPLines[];
HarmonicPattern* Patterns[];

string PatternLabel[9];

enum EnHarmonic {
   Gartley=1,
   Crab=2,
   DeepCrab=3,
   Bat=4,
   Butterfly=5,
   Shark=6,
   Cypher=7,
   ThreeDrives=8,
   FiveZero=9
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
//--- indicator buffers mapping
   
   SetIndexBuffer(0, ZigZagBuffer , INDICATOR_DATA);
   SetIndexBuffer(1, PatternSignal, INDICATOR_DATA);
   
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetInteger(1,PLOT_ARROW, 129); 
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT, 20);
   
//--- set short name and digits
   string short_name=StringFormat("iZigZag(%d,%d)", InpLength, InpErrorPercent);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
   
   PatternLabel[0] = "Gartley";
   PatternLabel[1] = "Crab";
   PatternLabel[2] = "DeepCrab";
   PatternLabel[3] = "Bat";
   PatternLabel[4] = "Butterfly";
   PatternLabel[5] = "Shark";
   PatternLabel[6] = "Cypher";
   PatternLabel[7] = "3Drives";
   PatternLabel[8] = "FiveZero";
   
}
  
void OnDeinit(const int reason)
{
   int size = ArraySize(Patterns);
   for(int i=0; i<size; ++i)
   {
      HarmonicPattern* p = Patterns[i];
      p.DeleteGraphic();
      delete p;
   }
   ArrayFree(Patterns);
}  

//+------------------------------------------------------------------+
//| Moving Averages Convergence/Divergence                           |
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
   if(rates_total<100)
      return(0);

   if(prev_calculated == rates_total-1)
      return prev_calculated;
   
   int start=prev_calculated;
   if(start<50)
   {
      ArrayInitialize(ZigZagBuffer, 0.0);
      ArrayInitialize(PatternSignal, 0.0);

      start=50;
   }

   bool foundOrChangedPattern = false;

   int prevIdxHi = -1;
   int prevIdxLo = -1;
   // if(!IsNewBar()) return prev_calculated;
   for(int i=start; i < rates_total-1 ; i++)
   {  
         
      ZigZagBuffer[i] = 0.0;
      
      int idxLastHi = calcLastHi( InpLength, i, high );
      int idxLastLo = calcLastLo( InpLength, i,  low );
   
      if(prevIdxHi == idxLastHi && prevIdxLo == idxLastLo)
      {
         // continue;
      }
      prevIdxHi = idxLastHi;
      prevIdxLo = idxLastLo;

      double pivotHi = i == idxLastHi ? high[i] : 0.0;
      double pivotLo = i == idxLastLo ?  low[i] : 0.0;

      int dirction = 0;
      int iff_1 = pivotLo && pivotHi == 0.0 ? -1 : dirction;
      dirction  = pivotHi && pivotLo == 0.0 ?  1 : iff_1;

      int idxArraySize = ArraySize(ZigZagIdx);
      if(idxArraySize == 0 ) 
      {
         if(dirction == 0)
            continue;
            
         ArrayResize(ZigZagIdx, 1);
         ZigZagIdx[0] = dirction == 1 ? idxLastHi : idxLastLo;
         ZigZagBuffer[ZigZagIdx[0]] = NormalizeDouble( (dirction == 1 ? pivotHi : pivotLo), _Digits);

         ArrayResize(ZigZagDir, 1);
         ZigZagDir[0] = 0;

         ArrayResize(ZigZagRatios, 1);
         ZigZagRatios[0] = 0;

         lastDirction = dirction;
         continue;
      }
         
      
      bool hasDirctionChanged = lastDirction != dirction;
      
      if (pivotHi != 0.0 || pivotLo != 0.0 )
      {
         lastDirction = dirction;
         bool isUp = dirction == 1;
         double newZigZagValue = isUp ? pivotHi : pivotLo;
         double oldZigZagValue = isUp ? low[idxLastLo] : high[idxLastHi];
         
         double lastLineLen = 0.0;
         double currentLineLen = MathAbs(oldZigZagValue - newZigZagValue);
         if ( idxArraySize > 3)
         {
            double prevPrice = ZigZagBuffer[ ZigZagIdx[idxArraySize-2]];
            // double lastPrice = ZigZagBuffer[idxArraySize-2];
            lastLineLen = MathAbs(prevPrice - oldZigZagValue);
         }
         
         double ratio = NormalizeDouble( (lastLineLen != 0.0 ? currentLineLen / lastLineLen : 0.0), 3);
         
         int clrDir = calcDirectionColor( dirction, newZigZagValue);
         
         if ( hasDirctionChanged == false )
         {
            if (oldZigZagValue * dirction <= newZigZagValue * dirction)
            {
               ZigZagBuffer[ZigZagIdx[idxArraySize-1]] = 0.0;

               ZigZagIdx[idxArraySize-1] = i;
               // ZigZagDir[idxArraySize-1] = clrDir;
               ZigZagRatios[idxArraySize-1] = ratio;

               ZigZagBuffer[ZigZagIdx[idxArraySize-1]] = NormalizeDouble( newZigZagValue, _Digits);
               // ZigZagColors[ZigZagIdx[idxArraySize-1]] = ToColorIndex(clrDir);
            }
         }
         else
         {
            
            bool outsideDeviationThreshold = MathAbs(newZigZagValue - oldZigZagValue) * 100 / oldZigZagValue > DeviationThreshold;
            if ( outsideDeviationThreshold )
            {
               ArrayResize(ZigZagIdx, idxArraySize+1);
               ZigZagIdx[idxArraySize] = i;
               
               ArrayResize(ZigZagDir, idxArraySize+1);
               ZigZagDir[idxArraySize] = clrDir;
               
               ArrayResize(ZigZagRatios, idxArraySize+1);
               ZigZagRatios[idxArraySize] = ratio;
               
               ZigZagBuffer[i] = NormalizeDouble( newZigZagValue, _Digits);
               
            }
         }    
   
         calculateZigZag(high, low, time);
   
         if(i>rates_total-3000) {
            if( calculatePatterns(time) ) {
               foundOrChangedPattern = true;
            }
         }
         
         
         if (idxArraySize > 10) 
         {
            ArrayRemove(ZigZagIdx,1,1);
            ArrayRemove(ZigZagDir,1,1);
            ArrayRemove(ZigZagRatios,1,1);
         }
      }
      else 
      {
         int size = ArraySize(Patterns);
         if(size>0)
         {
            HarmonicPattern* p = Patterns[size-1];
            if(p.D().m_index == i-1)
            {
               foundOrChangedPattern=false;
               double price = p.D().m_price;
               bool set = false;
               if(p.IsBullish() && price < close[i] )
               { set = true; }
               else if(!p.IsBullish() && price > close[i] )
               { set = true; }
                  
               if(set)
               {
                  PatternSignal[i] = price;
               }
            }
         }
      }
      
      if(i>rates_total-2000)
      {
         calculateDoublePattern(time);
         
      }
   }
  
   return(rates_total-1);
}

void calculateZigZag(const double &high[], const double &low[], const double &time[])
{

}

int ToColorIndex(int clrDirection)
{
   if(MathAbs(clrDirection) == 2 ) {
      return 2;
   }
   
   if(clrDirection == -1) {
      return 1;
   }
   return 0;
}

int calcDirectionColor(int direction, double lastPrice)
{
   int idxArraySize = ArraySize(ZigZagIdx);
   int clrDir = direction;
   if ( idxArraySize > 1)
   {
      double lastPivot = ZigZagBuffer[ZigZagIdx[idxArraySize-2]];
      clrDir = (direction * lastPrice > direction * lastPivot ? 2 : 1) * direction;
   }
   // lineColor = eDir == 2 ? bullishColor : eDir == 1 ? bullTrapColor : eDir == -1 ? bearTrapColor : bearishColor
   return clrDir;
}

void calculateDoublePattern(const datetime &time[])
{
   int idxArraySize = ArraySize(ZigZagIdx);
   bool doubleTop = false;
   bool doubleBottom = false;
   
   if ( idxArraySize < 4 || InpShowDoublePattern == false)
   {  return;
   }

   // ----  Berechnung  ----
   int idx = idxArraySize-2;
   
   int x = ZigZagIdx[idx];
   int highLow = ZigZagDir[idx];
   double value = ZigZagBuffer[x];

   int lx = ZigZagIdx[idx-1];
   int lhighLow = ZigZagDir[idx-1];
   double lvalue = ZigZagBuffer[lx];

   int llx = ZigZagIdx[idx-2];
   int llhighLow = ZigZagDir[idx-2];
   double llvalue = ZigZagBuffer[llx];

   double risk = MathAbs(value - llvalue);
   double reward = MathAbs(value - lvalue);
   double riskPerReward = NormalizeDouble( risk * 100.0 / (risk + reward), 2 );

   if ( highLow == 1 && llhighLow == 2 && lhighLow == -1 && riskPerReward < InpMaxRiskPerReward )
   {
      doubleTop = true;
   }
      
   if ( highLow == -1 && llhighLow == -2 && lhighLow == 1 && riskPerReward < InpMaxRiskPerReward )
   {
      doubleBottom = true;
   }
   
   if( !doubleTop && ! doubleBottom)
      return;
   
   // ----  Ausgabe ----
   int lineSize = ArraySize(DPLines);
   if(lineSize>10)
   {
      ArrayRemove(DPLines, 0, 1);
   }
   
   lineSize = ArraySize(DPLines);
   ArrayResize(DPLines, lineSize+1);
   
   int    x1 = x;
   double y1 = value;
   datetime t1 = time[x1];
   
   int    x2 = llx;
   double y2 = llvalue;
   datetime t2 = time[x2];

   DPLines[lineSize] = iLine::create(t1, x1, y1, t2, x2, y2, (doubleTop ? bearishColor : bullishColor) );
   
   DPLines[lineSize].UpdateGraphic();
   
   // count_index = doubleTop ? 7 : 6
   // labelText = (doubleTop ? 'DT - ' : 'DB - ') + str.tostring(riskPerReward)

}





bool calculatePatterns(const datetime &time[])
{
   bool wm_pattern = false;
   
   

bool gartley = true;
bool crab = true;
bool deepCrab = true;
bool bat = true;
bool butterfly = true;
bool shark = true;
bool cypher = true;
bool threeDrives = true;
bool fiveZero = true;
int wmtype[2];
iVector wmlines[4];
string tooltip = "";
   
   int idxArraySize = ArraySize(ZigZagIdx);
   if (idxArraySize >= 5)
   {
      double yxaRatio = ZigZagRatios[4];
      double xabRatio = ZigZagRatios[3];
      double abcRatio = ZigZagRatios[2];
      double bcdRatio = ZigZagRatios[1];

      iVector xa(ZigZagIdx[idxArraySize-5], ZigZagIdx[idxArraySize-4]); // array.get(zigzaglines, 4];
      iVector ab(ZigZagIdx[idxArraySize-4], ZigZagIdx[idxArraySize-3]); //  = array.get(zigzaglines, 3];
      iVector bc(ZigZagIdx[idxArraySize-3], ZigZagIdx[idxArraySize-2]); //  = array.get(zigzaglines, 2];
      iVector cd(ZigZagIdx[idxArraySize-2], ZigZagIdx[idxArraySize-1]); //  = array.get(zigzaglines, 1];

      double x = xa.get_y1(ZigZagBuffer);
      double a = xa.get_y2(ZigZagBuffer);
      double b = ab.get_y2(ZigZagBuffer);
      double c = cd.get_y1(ZigZagBuffer);
      double d = cd.get_y2(ZigZagBuffer);
      
      double val1 = MathAbs(a - d);
      double val2 = MathAbs(x - a);
      if(val2 == 0.0)
         return false;
         
      double xadRatio = NormalizeDouble( val1 / val2, 3);
      int dir = a > d ? 1 : -1;

      double maxP1 = MathMax(x, a);
      double maxP2 = MathMax(c, d);
      double minP1 = MathMin(x, a);
      double minP2 = MathMin(c, d);

      double highPoint = MathMin(maxP1, maxP2);
      double lowPoint  = MathMax(minP1, minP2);
      
      if ( b < highPoint && b > lowPoint )
      {
         //gartley
         if( gartley 
            && xabRatio >= 0.618 * err_min 
            && xabRatio <= 0.618 * err_max 
            && abcRatio >= 0.382 * err_min 
            && abcRatio <= 0.886 * err_max 
            && ((bcdRatio >= 1.272 * err_min && bcdRatio <= 1.618 * err_max ) || (xadRatio >= 0.786 * err_min && xadRatio <= 0.786 * err_max)) 
         ) {  
            wm_pattern = true;
            wmtype[1] = 0;
            tooltip = "Gartley";
            // array.set(wmLabels, 0, true)
         } else {
            // array.set(wmLabels, 0, false)
         }
                
         //Crab
         if (crab 
            && xabRatio >= 0.382 * err_min 
            && xabRatio <= 0.618 * err_max 
            && abcRatio >= 0.382 * err_min 
            && abcRatio <= 0.886 * err_max 
            && ( (bcdRatio >= 2.24 * err_min && bcdRatio <= 3.618 * err_max) || ( xadRatio >= 1.618 * err_min && xadRatio <= 1.618 * err_max) )
            ) { 
            wm_pattern = true;
            wmtype[1] = 1;
            tooltip = "Crab";

            // array.set(wmLabels, 1, true)
         } else {
            // array.set(wmLabels, 1, false)
         }
            
         //Deep Crab
         if (deepCrab 
            && xabRatio >= 0.886 * err_min 
            && xabRatio <= 0.886 * err_max 
            && abcRatio >= 0.382 * err_min 
            && abcRatio <= 0.886 * err_max 
            && ( (bcdRatio >= 2.00 * err_min && bcdRatio <= 3.618 * err_max ) || (xadRatio >= 1.618 * err_min && xadRatio <= 1.618 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = 2;
            tooltip = "Deep Crab";
            // array.set(wmLabels, 2, true)
         } else {
            // array.set(wmLabels, 2, false)
         }
            
         //Bat
         if (bat 
            && xabRatio >= 0.382 * err_min 
            && xabRatio <= 0.50 * err_max 
            && abcRatio >= 0.382 * err_min 
            && abcRatio <= 0.886 * err_max 
            && ( (bcdRatio >= 1.618 * err_min && bcdRatio <= 2.618 * err_max ) || (xadRatio >= 0.886 * err_min && xadRatio <= 0.886 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = 3;
            tooltip = "Bat";
            // array.set(wmLabels, 3, true)
         } else {
            /// array.set(wmLabels, 3, false)
         }
                
         //Butterfly
         if (butterfly 
            && xabRatio >= 0.786 * err_min 
            && xabRatio <= 0.786 * err_max 
            && abcRatio >= 0.382 * err_min 
            && abcRatio <= 0.886 * err_max 
            && ( (bcdRatio >= 1.618 * err_min && bcdRatio <= 2.618 * err_max ) || (xadRatio >= 1.272 * err_min && xadRatio <= 1.618 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = 4;
            tooltip = "Butterfly";
            // array.set(wmLabels, 4, true)
         } else {
            // array.set(wmLabels, 4, false)
         }
            
         //Shark
         if (shark 
            && abcRatio >= 1.13 * err_min 
            && abcRatio <= 1.618 * err_max 
            && bcdRatio >= 1.618 * err_min 
            && bcdRatio <= 2.24 * err_max 
            && xadRatio >= 0.886 * err_min 
            && xadRatio <= 1.13 * err_max
            ) { 
            wm_pattern = true;
            wmtype[1] = 5;
            tooltip = "Shark";
            // array.set(wmLabels, 5, true)
         } else {
            // array.set(wmLabels, 5, false)
         }
         
         //Cypher
         if (cypher 
            && xabRatio >= 0.382 * err_min 
            && xabRatio <= 0.618 * err_max 
            && abcRatio >= 1.13 * err_min 
            && abcRatio <= 1.414 * err_max 
            && ( (bcdRatio >= 1.272 * err_min && bcdRatio <= 2.00 * err_max) || (xadRatio >= 0.786 * err_min && xadRatio <= 0.786 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = 6;
            tooltip = "Cypher";
            // array.set(wmLabels, 6, true)
         } else {
            // array.set(wmLabels, 6, false)
         }
      }
      
                
      //3 drive
      if (threeDrives 
         && yxaRatio >= 0.618 * err_min 
         && yxaRatio <= 0.618 * err_max 
         && xabRatio >= 1.27 * err_min 
         && xabRatio <= 1.618 * err_max 
         && abcRatio >= 0.618 * err_min 
         && abcRatio <= 0.618 * err_max 
         && bcdRatio >= 1.27 * err_min 
         && bcdRatio <= 1.618 * err_max 
         ) {  
         wm_pattern = true;
         wmtype[1] = 7;
         tooltip = "3 Drive";
         // array.set(wmLabels, 7, true)
      } else {
         // array.set(wmLabels, 7, false)
      }
        
      //5-0
      if (fiveZero 
         && xabRatio >= 1.13 * err_min 
         && xabRatio <= 1.618 * err_max 
         && abcRatio >= 1.618 * err_min 
         && abcRatio <= 2.24 * err_max 
         && bcdRatio >= 0.5 * err_min 
         && bcdRatio <= 0.5 * err_max
         ) {  
         wm_pattern = true;
         wmtype[1] = 8;
         tooltip = "5-0";
         // array.set(wmLabels, 8, true)
      } else {
         // array.set(wmLabels, 8, false)
      }    
         
         
      if (wm_pattern)
      {
         wmlines[0]= xa;
         wmlines[1]= ab;
         wmlines[2]= bc;
         wmlines[3]= cd;
         wmtype[0] = dir;
      }   
      
   }            
   
   
   // ----- Ausgabe -----
   
   while(ArraySize(Patterns)>5) {
      HarmonicPattern* p = Patterns[0];
      p.DeleteGraphic();
      delete p;
      ArrayRemove(Patterns, 0, 1);
   }
   
   if(wm_pattern == false) {
      return false;
   }
   

   // siehe oben
   iVector xa = wmlines[0];
   iVector ab = wmlines[1];
   iVector bc = wmlines[2];
   iVector cd = wmlines[3];

   string typeAsString = PatternLabel[ wmtype[1] ];
   int dir = wmtype[0];
   uint trendColor = dir > 0 ? bullishColor : bearishColor;

   CPnt xPnt = xa.getStart(ZigZagBuffer, time);
   CPnt aPnt = xa.getEnd  (ZigZagBuffer, time);
   CPnt bPnt = bc.getStart(ZigZagBuffer, time);
   CPnt cPnt = bc.getEnd  (ZigZagBuffer, time);
   CPnt dPnt = cd.getEnd  (ZigZagBuffer, time);

   // prüfen ob es ein update ist
   bool addNewPattern=true;
   int size = ArraySize(Patterns);
   if(size>0)
   {
      HarmonicPattern* last = Patterns[size-1];
      if(last.X().m_time == xPnt.m_time)
      {
         addNewPattern=false;
         last.X(xPnt);
         last.A(aPnt);
         last.B(bPnt);
         last.C(cPnt);
         last.D(dPnt);
         last.CreateGraphic();
      }
   }
   
   if(addNewPattern)
   {
      ArrayResize(Patterns, size+1);
      Patterns[size] = new HarmonicPattern(typeAsString, dir);
      Patterns[size].X(xPnt);
      Patterns[size].A(aPnt);
      Patterns[size].B(bPnt);
      Patterns[size].C(cPnt);
      Patterns[size].D(dPnt);
      Patterns[size].Color(trendColor);
      Patterns[size].CreateGraphic();
   }      
   
//        isGartley = array.get(wmLabels, 0)
//        isCrab = array.get(wmLabels, 1)
//        isDeepCrab = array.get(wmLabels, 2)
//        isBat = array.get(wmLabels, 3)
//        isButterfly = array.get(wmLabels, 4)
//        isShark = array.get(wmLabels, 5)
//        isCypher = array.get(wmLabels, 6)
//        is3Drives = array.get(wmLabels, 7)
//        isFiveZero = array.get(wmLabels, 8)

        //labelText = isGartley ? 'Gartley' : ''
        //labelText += (isCrab ? (labelText == '' ? '' : '\n') + 'Crab' : '')
        //labelText += (isDeepCrab ? (labelText == '' ? '' : '\n') + 'Deep Crab' : '')
        //labelText += (isBat ? (labelText == '' ? '' : '\n') + 'Bat' : '')
        //labelText += (isButterfly ? (labelText == '' ? '' : '\n') + 'Butterfly' : '')
        //labelText += (isShark ? (labelText == '' ? '' : '\n') + 'Shark' : '')
        //labelText += (isCypher ? (labelText == '' ? '' : '\n') + 'Cypher' : '')
        //labelText += (is3Drives ? (labelText == '' ? '' : '\n') + '3 Drive' : '')
        //labelText += (isFiveZero ? (labelText == '' ? '' : '\n') + '5-0' : '')

        //baseLabel = label.new(x=bbar, y=b, text=labelText, yloc=dir < 1 ? yloc.abovebar : yloc.belowbar, color=trendColor, style=dir < 1 ? label.style_label_down : label.style_label_up, textcolor=color.black, size=size.normal)

      
   
   return wm_pattern;
}



int calcLastHi(const int length, const int barIdx, const double &prices[] )
{
   int idxLastHigh=-1;
   int start = barIdx-length;
   for( int i=start ; i<=barIdx; ++i)
   {
      if(idxLastHigh == -1) {
         idxLastHigh = i;
         continue;
      } 
      
      if(prices[i] > prices[idxLastHigh]) {
         idxLastHigh = i;
      }
   }
   
   return idxLastHigh;
}


int calcLastLo(const int length, const int barIdx, const double &prices[] )
{
   int idxLastLow=-1;
   int start = barIdx-length;
   for( int i=start ; i<=barIdx; ++i)
   {
      if(idxLastLow == -1) {
         idxLastLow = i;
         continue;
      } 
      
      if(prices[i] < prices[idxLastLow]) {
         idxLastLow = i;
      }
   }
   
   return idxLastLow;
}

//--- Detects when a "new bar" occurs, which is the same as when the previous bar has completed.
bool IsNewBar()
{
   string symbol = _Symbol;
   ENUM_TIMEFRAMES period = PERIOD_CURRENT;
   bool isNewBar = false;
   static datetime priorBarOpenTime = NULL;

//--- SERIES_LASTBAR_DATE == Open time of the last bar of the symbol-period
   const datetime currentBarOpenTime = (datetime) SeriesInfoInteger(symbol, period, SERIES_LASTBAR_DATE);

   if(priorBarOpenTime != currentBarOpenTime)
   {
      //--- Don't want new bar just because EA started
      isNewBar = (priorBarOpenTime == NULL) ? false : true; // priorBarOpenTime is only NULL once

      //--- Regardless of new bar, update the held bar time
      priorBarOpenTime = currentBarOpenTime;
   }

   return isNewBar;
}


bool AddLine(int idx, double p1, datetime t1, double p2, datetime t2, bool isDot=false)
{
   
   string name = "iZZL" + IntegerToString(idx);
   uint clr = clrAquamarine;
   long chartId = ChartID();
  
   if(ObjectFind(chartId, name) < 0 )
   {
      // if (!ObjectCreate( chartId, name, OBJ_HLINE, 0, 0, price))
      if (!ObjectCreate( chartId, name, OBJ_TREND, 0, t1, p1, t2,  p2))
      {
         PrintFormat("ObjectCreate(%s, HLINE) [1] failed: %d", name, GetLastError() );
      }
      else if (!ObjectSetInteger( 0, name, OBJPROP_COLOR, clr )) 
      {
         PrintFormat("ObjectSetInteger(%s, Color) [2] failed: %d", name, GetLastError() );
      }
   }
   else if(!ObjectMove(chartId, name, 0, t1, p1) || !ObjectMove(chartId, name, 1, t2, p2))
   {
      PrintFormat("ObjectMove(%s, OBJ_HLINE) [3] failed: %d", name, GetLastError() );
   }
   
   if(isDot)
   {
      ObjectSetInteger(chartId, name, OBJPROP_STYLE, STYLE_DOT);
   }
   
   return true;
}



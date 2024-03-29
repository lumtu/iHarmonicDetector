//+------------------------------------------------------------------+
//|                                                         MACD.mq5 |
//|                   Copyright 2009-2020, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2022-2022, lumtu Software"
#property link        "http://www.lumtu.de"
#property description "iHPDetector"

#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   7
//--- plot ZigZag
#property indicator_label1  "iZigZag"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrTomato
#property indicator_style1  STYLE_DASHDOT
#property indicator_width1  1

#property indicator_label2  "iPSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDarkGray
#property indicator_width2  5


#property indicator_type2   DRAW_NONE
#property indicator_type3   DRAW_NONE
#property indicator_type4   DRAW_NONE
#property indicator_type5   DRAW_NONE
#property indicator_type6   DRAW_NONE

#include "iLine.mqh"

input int InpLength      = 10; // Length minval=0, step=5)
input int InpErrorPercent= 10; // ErrorPercent minval=5, step=5, maxval=20)
input int InpMaxRiskPerReward = 40; // Max Risk Per Reward (Double Top/Bottom) minval=0, step=10

input bool InpShowDoublePattern = true; // Show Double Pattern


double ZigZagBuffer[]; // main buffer
double PatternD[]; // main buffer
double PatternC[]; // main buffer
double PatternB[]; // main buffer
double PatternA[]; // main buffer
double PatternX[]; // main buffer
double PatternSignal[]; // main buffer

double ExtPeaksBuffer[];
double ExtTroughsBuffer[];


int ZigZagIdx[]; // index buffer of zigzag points
int ZigZagDir[];
double ZigZagRatios[];
int lastDirction = 0;
int DeviationThreshold = 0;

input double AtrMultiplier=1.5; //ATR threshold for directional change
input int AtrPeriod=50; // Period for ATR calculation
input int MaxPeriod=10; // Max bar period before directional change
input int MinPeriod=3; // Min bar period before directional change
input bool RealTimeMode=true; // Draw tentative zigzag at newest bar

bool _lastDirection;
bool _realtimeChange;
int _lastIndex;
int _lastIndex2;
int _contraIndex;
double _atr;




double err_min = (100.0 - InpErrorPercent) / 100.0;
double err_max = (100.0 + InpErrorPercent) / 100.0;

uint bullishColor = clrSteelBlue;
uint bearishColor = clrDarkMagenta;

iLine DPLines[];
HarmonicPattern* Patterns[];


int min_rates_total=2;


bool UseAtrZigZag = false;
bool UseGannZigZag = true;
bool UseSimpleZigZag=true;

input uint GSv_range=2;


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
//--- indicator buffers mapping
   
   SetIndexBuffer(0, ZigZagBuffer , INDICATOR_DATA);
   SetIndexBuffer(1, PatternD, INDICATOR_DATA);
   SetIndexBuffer(2, PatternC, INDICATOR_DATA);
   SetIndexBuffer(3, PatternB, INDICATOR_DATA);
   SetIndexBuffer(4, PatternA, INDICATOR_DATA);
   SetIndexBuffer(5, PatternX, INDICATOR_DATA);
   SetIndexBuffer(6, PatternSignal, INDICATOR_DATA);
   SetIndexBuffer(7, ExtPeaksBuffer,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, ExtTroughsBuffer, INDICATOR_CALCULATIONS);
   
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetInteger(1,PLOT_ARROW, 129); 
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT, 20);
   
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,0.0);

   
//--- set short name and digits
   string short_name=StringFormat("iZigZag(%d,%d)", InpLength, InpErrorPercent);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
   
  
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
   
   // UseAtrZigZag = false;
   
   if(prev_calculated == rates_total-1)
      return prev_calculated;
   
   int start=prev_calculated;
      if(start<50)
      {
         ArrayInitialize(ZigZagBuffer, 0.0);
         ArrayInitialize(PatternSignal, 0.0);
         ArrayInitialize(PatternX, 0.0);
         ArrayInitialize(PatternA, 0.0);
         ArrayInitialize(PatternB, 0.0);
         ArrayInitialize(PatternC, 0.0);
         ArrayInitialize(PatternD, 0.0);

         ArrayInitialize(ExtPeaksBuffer, 0.0);
         ArrayInitialize(ExtTroughsBuffer, 0.0);
   
         start=50;
      }
      else
      {
         if(IsNewBar() == false) { return prev_calculated;   }
      }

      if(UseSimpleZigZag)
      {
         calculateSimpleZigZag(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, spread);
      }

      else if(UseGannZigZag)
      {
         ArraySetAsSeries(open,true);
         ArraySetAsSeries(high,true);
         ArraySetAsSeries(low,true);
         ArraySetAsSeries(close,true);
         ArraySetAsSeries(time,true);
         ArraySetAsSeries(ZigZagBuffer,true);
      
         calculateGannZigZag(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, spread);
         
         ArraySetAsSeries(open,false);
         ArraySetAsSeries(high,false);
         ArraySetAsSeries(low,false);
         ArraySetAsSeries(close,false);
         ArraySetAsSeries(time,false);
         ArraySetAsSeries(ZigZagBuffer,false);
      }
      else if(UseAtrZigZag)
      {
         calculateAtrZigZag( prev_calculated, rates_total, close, open, high, low, time);
      }
      else
      {
         calculateMyZigZag(start, rates_total, high, low, time);
      }

    int zigZagSize = ArraySize(ZigZagIdx);    
      if ( zigZagSize > 6) {
         start = ZigZagIdx[zigZagSize-5];
         ArrayResize(ZigZagIdx, 0);
         ArrayResize(ZigZagDir, 0);
         ArrayResize(ZigZagRatios, 0);
      }
      
      start = MathMax(start-20, 0);
      for(int i=start; i < rates_total-1 ; i++)
      {  
            if ( ArraySize(ZigZagIdx) > 10) 
            {
               ArrayRemove(ZigZagIdx,1,1);
               ArrayRemove(ZigZagDir,1,1);
               ArrayRemove(ZigZagRatios,1,1);
            }
      
            PatternSignal[i]=0.0;
            PatternX[i]=0.0;
            PatternA[i]=0.0;
            PatternB[i]=0.0;
            PatternC[i]=0.0;
            PatternD[i]=0.0;
            
            int idxArraySize = ArraySize(ZigZagIdx);
            bool changed = false;
            if(ZigZagBuffer[i] != 0.0)
            {  
               double ratio = 0;
               int clrDir   = 0;
               
               if(idxArraySize>2)
               {
                  double newZigZagValue  = ZigZagBuffer[i];
                  double prevZigZagValue = ZigZagBuffer[ZigZagIdx[idxArraySize-1]];
                  
                  int dirction = newZigZagValue>prevZigZagValue ? 1 : -1;
                  clrDir = calcDirectionColor( dirction, newZigZagValue);

                  double lastLineLen = 0.0;
                  double currentLineLen = MathAbs(prevZigZagValue - newZigZagValue);
                  if ( idxArraySize > 3)
                  {
                     double prevPrice = ZigZagBuffer[ ZigZagIdx[idxArraySize-2]];
                     // double lastPrice = ZigZagBuffer[idxArraySize-2];
                     lastLineLen = MathAbs(prevPrice - prevZigZagValue);
                  }
                     
                  ratio = NormalizeDouble( (lastLineLen != 0.0 ? currentLineLen / lastLineLen : 0.0), 3);
               
               }
               
               ArrayResize(ZigZagIdx, idxArraySize+1);
               ZigZagIdx[idxArraySize] = i;
               
               ArrayResize(ZigZagDir, idxArraySize+1);
               ZigZagDir[idxArraySize] = clrDir;
               
               ArrayResize(ZigZagRatios, idxArraySize+1);
               ZigZagRatios[idxArraySize] = ratio;
               
               // changed = true;
            }
            
     
            if(i<rates_total-3000 ) {
               continue;
            }
            
            idxArraySize = ArraySize(ZigZagIdx);
            if(idxArraySize<3) 
               continue;
            
            // if(ZigZagIdx[idxArraySize-1] < i-3) continue;
            
            calculateDoublePattern(rates_total, time);
            
            bool foundOrChangedPattern = false;
            if( calculatePatterns(time, i) ) {
               foundOrChangedPattern = true;
            }
            
            int size = ArraySize(Patterns);
            if(size>0 && ZigZagBuffer[i-1] != 0.0)
            {
               HarmonicPattern* p = Patterns[size-1];
              
               if( p.D().m_index>=rates_total-3 )
               {
                  p.Modified(false); 
                  
                  foundOrChangedPattern=false;
                  double price = p.D().m_price;
                  bool set = false;
                  if(p.IsBullish() && price < close[i] )
                  { set = true; }
                  else if(!p.IsBullish() && price > close[i] )
                  { set = true; }
                     
                  if(set)
                  {
                  
                     PatternSignal[i] = ((double)p.Type() * (p.IsBullish() ? 1: -1));
                     PatternD[i] = p.D().m_price;
                     PatternC[i] = p.C().m_price;
                     PatternB[i] = p.B().m_price;
                     PatternA[i] = p.A().m_price;
                     PatternX[i] = p.X().m_price;
                     
                     PrintFormat("Find index[%d/%d] [%s %s] |X:%.3f |A:%.3f |B:%.3f |C:%.3f |D:%.3f", 
                        p.D().m_index, i,
                        EnumToString(p.Type()), 
                        (PatternSignal[i] > 0 ? "/\\" : "\\/"),
                        PatternX[i],
                        PatternA[i],
                        PatternB[i],
                        PatternC[i],
                        PatternD[i]
                        );
                     if(1==1) {
                        int ggg = 0;
                     }
                  }
               }
            }
      }

   return (rates_total);
   
}

input int InpDepth    =12;  // Depth
input int InpDeviation=5;   // Deviation
input int InpBackstep =3;   // Back Step

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };

int       ExtRecalc=3;         // number of last extremes for recalculation


//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
//+------------------------------------------------------------------+
int calculateSimpleZigZag(const int rates_total,
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
//---
   int    i=0;
   int    start=0,extreme_counter=0,extreme_search=Extremum;
   int    shift=0,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double curlow=0,curhigh=0,last_high=0,last_low=0;
//--- initializing
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigZagBuffer,0.0);
      ArrayInitialize(ExtPeaksBuffer,0.0);
      ArrayInitialize(ExtTroughsBuffer,0.0);
      start=InpDepth;
     }

//--- ZigZag was already calculated before
   if(prev_calculated>0)
     {
      i=rates_total-1;
      //--- searching for the third extremum from the last uncompleted bar
      while(extreme_counter<ExtRecalc && i>rates_total-100)
        {
         res=ZigZagBuffer[i];
         if(res!=0.0)
            extreme_counter++;
         i--;
        }
      i++;
      start=i;

      //--- what type of exremum we search for
      if(ExtTroughsBuffer[i]!=0.0)
        {
         curlow=ExtTroughsBuffer[i];
         extreme_search=Peak;
        }
      else
        {
         curhigh=ExtPeaksBuffer[i];
         extreme_search=Bottom;
        }
      //--- clear indicator values
      for(i=start+1; i<rates_total && !IsStopped(); i++)
        {
         ZigZagBuffer[i] =0.0;
         ExtTroughsBuffer[i] =0.0;
         ExtPeaksBuffer[i]=0.0;
        }
     }

//--- searching for high and low extremes
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      //--- low
      val=low[Lowest(low,InpDepth,shift)];
      if(val==last_low)
         val=0.0;
      else
        {
         last_low=val;
         if((low[shift]-val)>InpDeviation*_Point)
            val=0.0;
         else
           {
            for(back=1; back<=InpBackstep; back++)
              {
               res=ExtTroughsBuffer[shift-back];
               if((res!=0) && (res>val))
                  ExtTroughsBuffer[shift-back]=0.0;
              }
           }
        }
      if(low[shift]==val)
         ExtTroughsBuffer[shift]=val;
      else
         ExtTroughsBuffer[shift]=0.0;
      //--- high
      val=high[Highest(high,InpDepth,shift)];
      if(val==last_high)
         val=0.0;
      else
        {
         last_high=val;
         if((val-high[shift])>InpDeviation*_Point)
            val=0.0;
         else
           {
            for(back=1; back<=InpBackstep; back++)
              {
               res=ExtPeaksBuffer[shift-back];
               if((res!=0) && (res<val))
                  ExtPeaksBuffer[shift-back]=0.0;
              }
           }
        }
      if(high[shift]==val)
         ExtPeaksBuffer[shift]=val;
      else
         ExtPeaksBuffer[shift]=0.0;
     }

//--- set last values
   if(extreme_search==0) // undefined values
     {
      last_low=0.0;
      last_high=0.0;
     }
   else
     {
      last_low=curlow;
      last_high=curhigh;
     }

//--- final selection of extreme points for ZigZag
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      res=0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low==0.0 && last_high==0.0)
              {
               if(ExtPeaksBuffer[shift]!=0)
                 {
                  last_high=high[shift];
                  last_high_pos=shift;
                  extreme_search=Bottom;
                  ZigZagBuffer[shift]=last_high;
                  res=1;
                 }
               if(ExtTroughsBuffer[shift]!=0.0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=Peak;
                  ZigZagBuffer[shift]=last_low;
                  res=1;
                 }
              }
            break;
         case Peak:
            if(ExtTroughsBuffer[shift]!=0.0 && ExtTroughsBuffer[shift]<last_low && ExtPeaksBuffer[shift]==0.0)
              {
               ZigZagBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=ExtTroughsBuffer[shift];
               ZigZagBuffer[shift]=last_low;
               res=1;
              }
            if(ExtPeaksBuffer[shift]!=0.0 && ExtTroughsBuffer[shift]==0.0)
              {
               last_high=ExtPeaksBuffer[shift];
               last_high_pos=shift;
               ZigZagBuffer[shift]=last_high;
               extreme_search=Bottom;
               res=1;
              }
            break;
         case Bottom:
            if(ExtPeaksBuffer[shift]!=0.0 && ExtPeaksBuffer[shift]>last_high && ExtTroughsBuffer[shift]==0.0)
              {
               ZigZagBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=ExtPeaksBuffer[shift];
               ZigZagBuffer[shift]=last_high;
              }
            if(ExtTroughsBuffer[shift]!=0.0 && ExtPeaksBuffer[shift]==0.0)
              {
               last_low=ExtTroughsBuffer[shift];
               last_low_pos=shift;
               ZigZagBuffer[shift]=last_low;
               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|  Search for the index of the highest bar                         |
//+------------------------------------------------------------------+
int Highest(const double &array[],const int depth,const int start)
  {
   if(start<0)
      return(0);

   double max=array[start];
   int    index=start;
//--- start searching
   for(int i=start-1; i>start-depth && i>=0; i--)
     {
      if(array[i]>max)
        {
         index=i;
         max=array[i];
        }
     }
//--- return index of the highest bar
   return(index);
  }
//+------------------------------------------------------------------+
//|  Search for the index of the lowest bar                          |
//+------------------------------------------------------------------+
int Lowest(const double &array[],const int depth,const int start)
  {
   if(start<0)
      return(0);

   double min=array[start];
   int    index=start;
//--- start searching
   for(int i=start-1; i>start-depth && i>=0; i--)
     {
      if(array[i]<min)
        {
         index=i;
         min=array[i];
        }
     }
//--- return index of the lowest bar
   return(index);
  }


//---
double h,l;
bool cur_h,cur_l;
bool draw_up,draw_dn,initfl;
int  fPoint_i,sPoint_i,s_up,s_dn,drawf,lb,idFile;

int calculateGannZigZag(const int rates_total,    // number of bars in history at the current tick
                const int prev_calculated,// amount of history in bars at the previous tick
                const datetime &time[],
                const double &open[],
                const double& high[],     // price array of maximums of price for the calculation of indicator
                const double& low[],      // price array of price lows for the indicator calculation
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- checking if the number of bars is enough for the calculation
   if(rates_total<min_rates_total) 
      return(0);
   
//--- declaration of integer variables
   int i,bar,bar1,limit,count;
//--- calculations of the starting number limit for the bar recalculation loop
   if(prev_calculated>rates_total || prev_calculated<=0)// checking for the first start of calculation of an indicator
     {
      limit=rates_total-min_rates_total; // starting index for the calculation of all bars
      initfl=0;
      draw_up=0;
      draw_dn=0;
      initfl=0;
      cur_h=0;
      cur_l=0;
     }
   else
     {
      limit=rates_total-prev_calculated; // starting index for the calculation of new bars
     }
//--- The starting initialization
   if(initfl!=1) gannInit(rates_total,open,high,low,close);
   int bars2=rates_total-2;
   int bars1=rates_total-1;
//--- main calculation loop of the indicator
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      bar1=bar+1;
      count=bars1-bar;
      ZigZagBuffer[bar]=0.0;
      //--- if an extremum was drawn on the previous bar
      if(ZigZagBuffer[bar1]>0 && lb!=count)
        {
         if(draw_up) s_dn=0;
         else if(draw_dn) s_up=0;
        }
      if(lb!=count)
        {
         cur_h=0;
         cur_l=0;
        }
      if(bar>bars2-drawf || (high[bar]<=high[bar1] && low[bar]>=low[bar1])) continue;
      if(draw_up)
        {
         //--- if the line is directed upwards
         if(high[bar]>h)
           {
            //--- if a new maximum has been reached
            h=high[bar];
            cur_h=1;
           }
         if(low[bar]<l)
           {
            //--- if a new minimum has been reached
            l=low[bar];
            //--- if this is not the same bar
            if(lb!=count || cur_l!=1)s_dn++;
            cur_l=1;
           }
         //--- if the counters are equal
         if(s_up==s_dn)
           {
            //--- if th elast bar is a new maximum and minimum at the same time
            if(cur_h==cur_l && cur_l==1)
              {
               //--- if a candlestick is bearish
               if(close[bar]<=open[bar])
                 {
                  draw_up=0;
                  draw_dn=1;
                  fPoint_i=sPoint_i;
                  sPoint_i=count;
                  ZigZagBuffer[bar]=l;
                  for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                 }
               else
                 {
                  //--- if a candlestick is bullish
                  sPoint_i=count;
                  ZigZagBuffer[bar]=h;
                  for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                 }
              }
            else
              {
               //--- if th elast bar is only a new maximum
               if(cur_h==1)
                 {
                  sPoint_i=count;
                  ZigZagBuffer[bar]=h;
                  l=low[bar];
                  for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                 }
               else
                 {
                  if(cur_l==1)
                    {
                     //--- if th elast bar is only a new minimum
                     draw_up=0;
                     draw_dn=1;
                     fPoint_i=sPoint_i;
                     sPoint_i=count;
                     ZigZagBuffer[bar]=l;
                     h=high[bar];
                     for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                    }
                 }
              }
           }
         else
           {
            //--- otherwise, if there is no explicit change of direction (the Dn candlestick counter is not equal to GSv_range)
            //--- if a new maximum has been reached
            if(cur_h==1)
              {
               sPoint_i=count;
               ZigZagBuffer[bar]=h;
               for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
               l=low[bar];
              }
           }
        }
      else
        {
         //--- if the line is directed downwards
         if(high[bar]>h)
           {
            //--- if a new maximum has been reached
            h=high[bar];
            if(lb!=count || cur_h!=1)s_up++;
            cur_h=1;
            //--- if this is not the same bar
           }
         if(low[bar]<l)
           {
            //--- if a new minimum has been reached
            l=low[bar];
            cur_l=1;
           }
         //--- if the counters are equal 
         if(s_up==s_dn)
           {
            //--- if th elast bar is a new maximum and minimum at the same time
            if(cur_h==cur_l && cur_l==1)
              {
               //--- if a candlestick is bearish
               if(close[bar]<=open[bar])
                 {
                  sPoint_i=count;
                  ZigZagBuffer[bar]=l;
                  for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                 }
               else
                 {
                  //--- if a candlestick is bullish
                  draw_up=1;
                  draw_dn=0;
                  fPoint_i=sPoint_i;
                  sPoint_i=count;
                  ZigZagBuffer[bar]=h;
                  for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                 }
              }
            else
              {
               //--- if th elast bar is only a new maximum
               if(cur_h==1)
                 {
                  draw_up=1;
                  draw_dn=0;
                  fPoint_i=sPoint_i;
                  sPoint_i=count;
                  ZigZagBuffer[bar]=h;
                  l=low[bar];
                  for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                 }
               else
                 {
                  if(cur_l==1)
                    {
                     //--- if th elast bar is only a new minimum
                     sPoint_i=count;
                     ZigZagBuffer[bar]=l;
                     h=high[bar];
                     for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
                    }
                 }
              }
           }
         else
           {
            //--- otherwise, if there is no explicit change of direction (the Up candlestick counter is not equal to GSv_range)
            //--- if a new minimum has been reached
            if(cur_l==1)
              {
               sPoint_i=count;
               ZigZagBuffer[bar]=l;
               for(i=bars2-fPoint_i; i>bar; i--) ZigZagBuffer[i]=0.0;
               h=high[bar];
              }
           }
        }
      if(lb!=count) lb=count;
     }
//---     
   return(rates_total);
}



int calculateAtrZigZag(
   const int &prev_calculated,const int &rates_total, 
   const double &close[], const double &open[],
   const double &high[], const double &low[], const datetime &time[])
{

   int start;
   if(prev_calculated>rates_total || prev_calculated<=0)
     {
      start=1;
      _lastIndex=0;
      _lastIndex2=0;
      _contraIndex=0;
      _atr=0;
      _realtimeChange=false;
     }
   else
      start=MathMax(1,prev_calculated-1);

   double atr=_atr;
   
//--- main loop
   for(int bar=start; bar<rates_total-(RealTimeMode?0:1); bar++)
     {
      
      bool realtimeBar=bar==rates_total-1;
      
      //--- Update ATR and other tasks
      if(!realtimeBar)
        {
         double tr=MathMax(high[bar],close[bar-1])-MathMin(low[bar],close[bar-1]);
         atr+=(tr-atr)*(2.0/(1.0+AtrPeriod));
         _atr=atr;
         
         if(_realtimeChange && RealTimeMode)
           {
            if(_lastDirection) {
               ExtPeaksBuffer[_lastIndex]=high[_lastIndex];
               ZigZagBuffer[_lastIndex]=low[_lastIndex];
            } else { 
               ExtTroughsBuffer[_lastIndex]=low[_lastIndex];
               ZigZagBuffer[_lastIndex]=high[_lastIndex];
            } 
            ExtPeaksBuffer[rates_total-1]=0;
            ExtTroughsBuffer[rates_total-1]=0;
            _realtimeChange=false;
           }
           
         //---
         ExtPeaksBuffer[bar]=0;
         ExtTroughsBuffer[bar]=0;
         ZigZagBuffer[bar]=0;
        }
        
        
      //--- Conditions
      bool shouldntChange=bar-_lastIndex<MinPeriod;
      bool shallChange=bar-_lastIndex>MaxPeriod;
      bool mustChange,shouldChange,canChange;
      
      if(_lastDirection)
        {
         mustChange=low[bar]<low[_lastIndex2];
         shouldChange=ExtPeaksBuffer[_lastIndex]-low[bar]>atr*AtrMultiplier;
         canChange=low[bar]<low[_contraIndex];
        }
      else
        {
         mustChange=high[bar]>high[_lastIndex2];
         shouldChange=high[bar]-ExtTroughsBuffer[_lastIndex]>atr*AtrMultiplier;
         canChange=high[bar]>high[_contraIndex];
        }
        
      bool changeNow=mustChange || (canChange && shouldChange && !shouldntChange);
      
      //--- Algorithm realtime
        
        
         if(canChange)
            _contraIndex=bar;
            
            
         if(_lastDirection)
           {
           
            if(high[bar]>ExtPeaksBuffer[_lastIndex])
              { // weiter nach oben
               ExtPeaksBuffer[_lastIndex]=0;
               ExtPeaksBuffer[bar]=high[bar];
               ZigZagBuffer[_lastIndex]=0;
               ZigZagBuffer[bar]=high[bar];
               
               if(open[bar]>close[bar])
                 {  // schliessen gruen
                  shouldntChange=0<MinPeriod;
                  shouldChange=ExtPeaksBuffer[bar]-low[bar]>atr*AtrMultiplier;
                  changeNow=mustChange || (canChange && shouldChange && !shouldntChange);
                  if(changeNow)
                    {
                     // Richtung ändern 
                     ZigZagBuffer[_lastIndex]=high[_lastIndex];
                     
                     ExtTroughsBuffer[bar]=low[bar];
                     _lastDirection=false;
                     _lastIndex2=bar;
                    }
                 }
               else if(changeNow)
                 {
                     // Richtung ändern 
                     ZigZagBuffer[_lastIndex]=low[_lastIndex];

                  ExtPeaksBuffer[_lastIndex]=high[_lastIndex];
                  ExtTroughsBuffer[bar]=low[bar];
                  _lastIndex2=bar;
                 }
               _lastIndex=bar;
               _contraIndex=bar;
              }
            else if(changeNow)
              {
               // Richtung ändern 
               ZigZagBuffer[_lastIndex]=high[_lastIndex];

               ExtTroughsBuffer[bar]=low[bar];
               _lastDirection=false;
               _lastIndex2=_lastIndex;
               _lastIndex=bar;
               _contraIndex=bar;
              }
            else if(shallChange)
              {
               int startSkip=ExtTroughsBuffer[_lastIndex]==0?0:1;
               if(open[_lastIndex]<close[_lastIndex] && startSkip==0) startSkip++;
               
               bar=ArrayMinimum(low,_lastIndex+startSkip,bar-_lastIndex-startSkip+1);
               
               // Richtung ändern 
               ZigZagBuffer[_lastIndex]=high[_lastIndex];

               ExtTroughsBuffer[bar]=low[bar];
               _lastDirection=false;
               _lastIndex2=_lastIndex;
               _lastIndex=bar;
               _contraIndex=bar;
              }
              
           }
         else
           {
            //--- bear trend
            if(low[bar]<ExtTroughsBuffer[_lastIndex])
              {
               ExtTroughsBuffer[_lastIndex]=0;
               ExtTroughsBuffer[bar]=low[bar];
               ZigZagBuffer[_lastIndex]=0;
               ZigZagBuffer[bar]=low[bar];
               
               if(open[bar]<close[bar])
                 {
                  shouldntChange=0<MinPeriod;
                  shouldChange=high[bar]-ExtTroughsBuffer[bar]>atr*AtrMultiplier;
                  changeNow=mustChange || (canChange && shouldChange && !shouldntChange);
                  if(changeNow)
                    {
                     // Richtung ändern 
                     ZigZagBuffer[_lastIndex]=low[_lastIndex];

                     ExtPeaksBuffer[bar]=high[bar];
                     _lastDirection=true;
                     _lastIndex2=bar;
                    }
                 }
               else if(changeNow)
                 {
                     // Richtung ändern 
                     ZigZagBuffer[_lastIndex]=low[_lastIndex];
                 
                  ExtTroughsBuffer[_lastIndex]=low[_lastIndex];
                  ExtPeaksBuffer[bar]=high[bar];
                  _lastIndex2=bar;
                 }
               _lastIndex=bar;
               _contraIndex=bar;
              }
            else if(changeNow)
              {
               // Richtung ändern 
               ZigZagBuffer[_lastIndex]=low[_lastIndex];
               
               ExtPeaksBuffer[bar]=high[bar];
               _lastDirection=true;
               _lastIndex2=_lastIndex;
               _lastIndex=bar;
               _contraIndex=bar;
              }
            else if(shallChange)
              {
               int startSkip=ExtPeaksBuffer[_lastIndex]==0?0:1;
               if(open[_lastIndex]>close[_lastIndex] && startSkip==0) startSkip++;
               
               bar=ArrayMaximum(high,_lastIndex+startSkip,bar-_lastIndex-startSkip+1);
               
               // Richtung ändern 
               ZigZagBuffer[_lastIndex2]=high[_lastIndex2];

               ExtPeaksBuffer[bar]=high[bar];
               _lastDirection=true;
               _lastIndex2=_lastIndex;
               _lastIndex=bar;
               _contraIndex=bar;
              }
           }
           

           
         //---
         ExtPeaksBuffer[rates_total-1]=0;
         ExtTroughsBuffer[rates_total-1]=0;
        }
     
//--- return value of prev_calculated for next call
   return(rates_total);

}



//+------------------------------------------------------------------+
//| The function of indicator's first initialization                 |
//+------------------------------------------------------------------+
void gannInit(const int bars,
            const double &Open[],
            const double &High[],
            const double &Low[],
            const double &Close[])
  {
//--- 
   int index,index1;
   int bars1=bars-1;
   fPoint_i=0;
   h=High[bars1];
   l=Low[bars1];
   for(index=bars-2; index>=0; index--)
     {
      index1=index+1;
      if(High[index]>High[index1] || Low[index]<Low[index1])
        {
         if(High[index]>h && High[index]>High[index1]) s_up++;
         if(Low[index]<l && Low[index]<Low[index1]) s_dn++;
        }
      else continue;
      if(s_up==s_dn && s_up==GSv_range)
        {
         h=High[index];
         l=Low[index];
         sPoint_i=bars1-index;
         if(Close[index]>=Open[index])
           {
            s_dn=0;
            ZigZagBuffer[bars1]=Low[bars1];
            ZigZagBuffer[index]=High[index];
            draw_up=1;
            break;
           }
         else
           {
            s_up=0;
            ZigZagBuffer[bars1]=High[bars1];
            ZigZagBuffer[index]=Low[index];
            draw_dn=1;
            break;
           }
        }
      else
        {
         h=High[index];
         l=Low[index];
         sPoint_i=bars1-index;
         if(s_up==GSv_range)
           {
            s_dn=0;
            ZigZagBuffer[bars1]=Low[bars1];
            ZigZagBuffer[index]=High[index];
            draw_up=1;
            break;
           }
         else
           {
            if(s_dn==GSv_range)
              {
               s_up=0;
               ZigZagBuffer[bars1]=High[bars1];
               ZigZagBuffer[index]=Low[index];
               draw_dn=1;
               break;
              }
           }
        }
     }
   initfl=1;
   drawf=sPoint_i;
//---
  }
//+------------------------------------------------------------------+




void calculateMyZigZag(
   const int &prev_calculated,const int &rates_total, 
   const double &high[], const double &low[], const datetime &time[])
{

   int lastZigZagIndex = 0;
   int lastCurrIndex = 0;
   for(int currIndex = prev_calculated; currIndex<rates_total-1; currIndex++ )
   {
      ZigZagBuffer[currIndex]=0.0;
      int idxLastHi = calcLastHi( InpLength, currIndex, high );
      int idxLastLo = calcLastLo( InpLength, currIndex,  low );
   
      double pivotHi = currIndex == idxLastHi ? high[currIndex] : 0.0;
      double pivotLo = currIndex == idxLastLo ?  low[currIndex] : 0.0;
      
      int dirction = 0;
      int iff_1 = pivotLo && pivotHi == 0.0 ? -1 : dirction;
      dirction  = pivotHi && pivotLo == 0.0 ?  1 : iff_1;
      
      if(dirction == 0)
         continue;
   
         
      bool hasDirctionChanged = lastDirction != dirction;
        
      if (pivotHi != 0.0 || pivotLo != 0.0 )
      {
         lastDirction = dirction;   
         bool isUp = dirction == 1;
         double newZigZagValue = isUp ? pivotHi : pivotLo;
         double oldZigZagValue = isUp ? low[idxLastLo] : high[idxLastHi];
         
         if ( hasDirctionChanged == false )
         {
            if (oldZigZagValue * dirction <= newZigZagValue * dirction)
            {
               ZigZagBuffer[lastCurrIndex] = 0.0;
               
               lastCurrIndex = currIndex;
               ZigZagBuffer[currIndex] = NormalizeDouble( newZigZagValue, _Digits);
            }
         }
         else
         {
            bool outsideDeviationThreshold = MathAbs(newZigZagValue - oldZigZagValue) * 100 / oldZigZagValue > DeviationThreshold;
            if ( outsideDeviationThreshold )
            {
               lastZigZagIndex = currIndex;       
               lastCurrIndex = 0;
               ZigZagBuffer[currIndex] = NormalizeDouble( newZigZagValue, _Digits);
            }
         }    
      }
   }
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

int lastDoublePatternIndex=-1;
void calculateDoublePattern(int rates_total, const datetime &time[])
{
    if(!lastDoublePatternIndex == rates_total) {
        return;
        }
        
   lastDoublePatternIndex = rates_total;    
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
   double val = (risk + reward);
   if(val == 0.0) val=1;
   double riskPerReward = NormalizeDouble( risk * 100.0 /val , 2 );

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

   int    x1 = x;
   double y1 = value;
   datetime t1 = time[x1];
   
   int    x2 = llx;
   double y2 = llvalue;
   datetime t2 = time[x2];

    if(x2 < rates_total -3 ) {
        return;
    }
   // ----  Ausgabe ----
   int lineSize = ArraySize(DPLines);
   if(lineSize>10)
   {
      ArrayRemove(DPLines, 0, 1);
   }
   
   lineSize = ArraySize(DPLines);
   ArrayResize(DPLines, lineSize+1);
   

   PatternSignal[x2] = ((double)EnHarmonic::DoublePattern * (doubleTop ? 1: -1));
   PatternD[x2] = y2;

   DPLines[lineSize] = iLine::create(t1, x1, y1, t2, x2, y2, (doubleTop ? bearishColor : bullishColor) );
   
   DPLines[lineSize].UpdateGraphic();
   
   // count_index = doubleTop ? 7 : 6
   // labelText = (doubleTop ? 'DT - ' : 'DB - ') + str.tostring(riskPerReward)

}





bool calculatePatterns(const datetime &time[], int currBar)
{
   bool wm_pattern = false;
   
   

bool gartley = true;
bool crab = true;
bool deepCrab = true;
bool bat = true;
bool butterfly = true;
bool shark = true;
bool cypher = true;
bool threeDrives = false;
bool fiveZero = false;
int wmtype[2];
iVector wmlines[4];

   int idxOffset = ((UseGannZigZag || UseAtrZigZag) ? 0:0);
   
   int idxArraySize = ArraySize(ZigZagIdx);
   if (idxArraySize >= 5)
   {
      // if(ZigZagIdx[idxArraySize-1-idxOffset])
   
      double yxaRatio = ZigZagRatios[idxArraySize-4-idxOffset];
      double xabRatio = ZigZagRatios[idxArraySize-3-idxOffset];
      double abcRatio = ZigZagRatios[idxArraySize-2-idxOffset];
      double bcdRatio = ZigZagRatios[idxArraySize-1-idxOffset];

      iVector xa(ZigZagIdx[idxArraySize-5-idxOffset], ZigZagIdx[idxArraySize-4-idxOffset]); // array.get(zigzaglines, 4];
      iVector ab(ZigZagIdx[idxArraySize-4-idxOffset], ZigZagIdx[idxArraySize-3-idxOffset]); //  = array.get(zigzaglines, 3];
      iVector bc(ZigZagIdx[idxArraySize-3-idxOffset], ZigZagIdx[idxArraySize-2-idxOffset]); //  = array.get(zigzaglines, 2];
      iVector cd(ZigZagIdx[idxArraySize-2-idxOffset], ZigZagIdx[idxArraySize-1-idxOffset]); //  = array.get(zigzaglines, 1];

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
            && ( dir > 0 ? (a > c) : (a < c) )
            && ((bcdRatio >= 1.272 * err_min && bcdRatio <= 1.618 * err_max ) || (xadRatio >= 0.786 * err_min && xadRatio <= 0.786 * err_max)) 
         ) {  
            wm_pattern = true;
            wmtype[1] = EnHarmonic::Gartley;
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
            && ( dir > 0 ? (a > c) : (a < c) )
            && ( (bcdRatio >= 2.24 * err_min && bcdRatio <= 3.618 * err_max) || ( xadRatio >= 1.618 * err_min && xadRatio <= 1.618 * err_max) )
            ) { 
            wm_pattern = true;
            wmtype[1] = EnHarmonic::Crab;

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
            && ( dir > 0 ? (a > c) : (a < c) )
            && ( (bcdRatio >= 2.00 * err_min && bcdRatio <= 3.618 * err_max ) || (xadRatio >= 1.618 * err_min && xadRatio <= 1.618 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = EnHarmonic::DeepCrab;
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
            && ( dir > 0 ? (a > c) : (a < c) )
            && ( (bcdRatio >= 1.618 * err_min && bcdRatio <= 2.618 * err_max ) || (xadRatio >= 0.886 * err_min && xadRatio <= 0.886 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = EnHarmonic::Bat;
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
            && ( dir > 0 ? (a > c) : (a < c) )
            && ( (bcdRatio >= 1.618 * err_min && bcdRatio <= 2.618 * err_max ) || (xadRatio >= 1.272 * err_min && xadRatio <= 1.618 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = EnHarmonic::Butterfly;
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
            && ( dir > 0 ? (a < c) : (a > c) )
            ) { 
            wm_pattern = true;
            wmtype[1] = EnHarmonic::Shark;
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
            && ( dir > 0 ? (a < c) : (a > c) )
            && ( (bcdRatio >= 1.272 * err_min && bcdRatio <= 2.00 * err_max) || (xadRatio >= 0.786 * err_min && xadRatio <= 0.786 * err_max) )
            ) {  
            wm_pattern = true;
            wmtype[1] = EnHarmonic::Cypher;
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
         wmtype[1] = EnHarmonic::ThreeDrives;
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
         wmtype[1] = EnHarmonic::FiveZero;
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

   EnHarmonic type = (EnHarmonic)wmtype[1];
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
      Patterns[size] = new HarmonicPattern(type, dir);
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



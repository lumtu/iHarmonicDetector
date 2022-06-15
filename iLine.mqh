
class iLine
{
public:
    
    static iLine create(const datetime &_t1, const int &_x1, double &_y1, 
                       const datetime &_t2, const int &_x2, double &_y2, 
                       color _clr=clrDarkCyan, bool _isDot=false)
    {
      iLine l;
      l.x1  = _x1;
      l.y1  = _y1;
      l.t1  = _t1;

      l.x2  = _x2;
      l.y2  = _y2;
      l.t2  = _t2;

      l.clr = _clr;
      l.isDot = _isDot;

      return l;
    }
    
protected:
    int x1;
    double y1;
    datetime t1;

    int x2;
    double y2;
    datetime t2;

    color clr;
    string objName;
    bool isDot;
    
public:
    iLine()
      : x1(0)
      , y1(0)
      , t1(0)
      , x2(0)
      , y2(0)
      , t2(0)
      , clr(clrDarkCyan)
      , isDot(false)
      { }
      
    iLine(const iLine& cpy) {
      if( &this == &cpy)
         return;
      
      this.x1 = cpy.x1;
      this.x2 = cpy.x2;
      this.y1 = cpy.y1;
      this.y2 = cpy.y2;
      this.t1 = cpy.t1;
      this.t2 = cpy.t2;
      this.isDot = cpy.isDot;
      this.objName = ((iLine)cpy).name();
      
      // UpdateGraphic();
    }

    ~iLine()
    {
      if( ObjectFind(ChartID(), name() ) >= 0 ) {
         ObjectDelete(ChartID(), name() );  
      }
    }
    
   void UpdateGraphic(string tooltip="")
   {
      long chartId = ChartID();
      string name = name();
      if(ObjectFind(chartId, name ) < 0 )
      {
         // if (!ObjectCreate( chartId, name, OBJ_HLINE, 0, 0, price))
         if (!ObjectCreate( chartId, name, OBJ_TREND, 0, t1, y1, t2, y2))
         {
            PrintFormat("ObjectCreate(%s, HLINE) [1] failed: %d", name, GetLastError() );
         }
         else if (!ObjectSetInteger( 0, name, OBJPROP_COLOR, clr )) 
         {
            PrintFormat("ObjectSetInteger(%s, Color) [2] failed: %d", name, GetLastError() );
         }
         else if (!ObjectSetInteger( 0, name, OBJPROP_WIDTH, 5)) 
         {
            PrintFormat("ObjectSetInteger(%s, Width) [3] failed: %d", name, GetLastError() );
         }
         else if (!ObjectSetString( 0, name, OBJPROP_TOOLTIP, tooltip)) 
         {
            PrintFormat("ObjectSetInteger(%s, Width) [3] failed: %d", name, GetLastError() );
         }
         
      }
      else if(!ObjectMove(chartId, name, 0, t1, y1) || !ObjectMove(chartId, name, 1, t2, y2))
      {
         PrintFormat("ObjectMove(%s, OBJ_HLINE) [4] failed: %d", name, GetLastError() );
      }
      
      if(isDot)
      {
         ObjectSetInteger(chartId, name, OBJPROP_STYLE, STYLE_DOT);
      }
   }
   
   string name() 
   {
      static ulong lineCount = 0;
      if( StringLen(objName)==0) {
         objName = StringFormat("L-%d", lineCount++);
      }
      return objName;
   }
};




class CPnt
{
public:
   int m_index;
   double m_price;
   datetime m_time;
   
   CPnt(int index = 0, double price=0.0, datetime time=0)
      : m_index(index)
      , m_price(price)
      , m_time(time)
   {}
   
   CPnt(const CPnt &cpy)
   {
      m_index = cpy.m_index;
      m_price = cpy.m_price;
      m_time = cpy.m_time;
   }
};


class iVector
{
public:
   CPnt getStart(const double &buffer[], const datetime &time[])
   { return CPnt(x1, buffer[x1], time[x1]); }

   CPnt getEnd(const double &buffer[], const datetime &time[])
   { return CPnt(x2, buffer[x2], time[x2]); }
   
   /*
   datetime get_t1(const datetime &time[]) { return time[x1]; }
   datetime get_t2(const datetime &time[]) { return time[x2]; }
   */
   double get_y1(const double &buffer[]) { return buffer[x1]; }
   double get_y2(const double &buffer[]) { return buffer[x2]; }
   
public:
   int x1;
   int x2;
   iVector(int _x1=0, int _x2=0 )
      : x1(_x1)
      , x2(_x2)
   {}
   
   iVector(const iVector &cpy)
   {
      x1 = cpy.x1;
      x2 = cpy.x2;
   }
};


class HarmonicPattern
{
   CPnt m_xPnt;
   CPnt m_aPnt;
   CPnt m_bPnt;
   CPnt m_cPnt;
   CPnt m_dPnt;
   string m_name;
   uint m_color;

   string m_xaName;
   string m_xatt;
   string m_abName;
   string m_abtt;
   string m_bcName;
   string m_bctt;
   string m_cdName;
   string m_cdtt;
   string m_xbName;
   string m_xbtt;
   string m_xdName;
   string m_xdtt;
   string m_bdName;
   string m_bdtt;
   
   int m_direction;
public:
   ulong m_instanceId;
   
public:
   HarmonicPattern(string name, int direction)
      : m_instanceId(0)
      , m_name(name)
      , m_direction(direction)
   {
      static ulong sm_counter=0;
      m_instanceId = ++sm_counter;
      
      m_xaName   = StringFormat("L-XA-(%d)", m_instanceId);
      m_xatt = StringFormat("%s (XA)", m_name );
      m_abName   = StringFormat("L-AB-(%d)", m_instanceId);
      m_abtt = StringFormat("%s (AB)", m_name );
      m_bcName   = StringFormat("L-BC-(%d)", m_instanceId);
      m_bctt = StringFormat("%s (BC)", m_name );
      m_cdName   = StringFormat("L-CD-(%d)", m_instanceId);
      m_cdtt = StringFormat("%s (CD)", m_name );
      m_xbName   = StringFormat("L-XB-(%d)", m_instanceId);
      m_xbtt = StringFormat("%s (XB)", m_name );
      m_xdName   = StringFormat("L-XD-(%d)", m_instanceId);
      m_xdtt = StringFormat("%s (XD)", m_name );
      m_bdName   = StringFormat("L-BD-(%d)", m_instanceId);
      m_bdtt = StringFormat("%s (BD)", m_name );
      
   }

   HarmonicPattern(const HarmonicPattern &cpy)
   {
      m_instanceId = cpy.m_instanceId;
      m_xPnt = cpy.m_xPnt;
      m_aPnt = cpy.m_aPnt;
      m_bPnt = cpy.m_bPnt;
      m_cPnt = cpy.m_cPnt;
      m_dPnt = cpy.m_dPnt;
      m_name = cpy.m_name;
   }
   
   ~HarmonicPattern()
   { }
   
   bool IsBullish() {return m_direction>0; }
   
   void A(const CPnt &pnt) { m_aPnt = pnt;}
   CPnt* A(){ return &m_aPnt; }

   void B(const CPnt &pnt) { m_bPnt = pnt;}
   CPnt* B(){ return &m_bPnt; }

   void C(const CPnt &pnt) { m_cPnt = pnt;}
   CPnt* C(){ return &m_cPnt; }

   void D(const CPnt &pnt) { m_dPnt = pnt;}
   CPnt* D(){ return &m_dPnt; }

   void X(const CPnt &pnt) { m_xPnt = pnt;}
   CPnt* X(){ return &m_xPnt; }
   
   void Color(uint clr) { m_color = clr; }
   
   void DeleteGraphic()
   {
      DeleteObject(m_xaName);
      DeleteObject(m_abName);
      DeleteObject(m_bcName);
      DeleteObject(m_cdName);
      DeleteObject(m_xbName);
      DeleteObject(m_xdName);
      DeleteObject(m_bdName);
   }
   
   void DeleteObject(string name)
   {
      if( ObjectFind(ChartID(), name ) >= 0 ) {
         ObjectDelete(ChartID(), name );  
      }
   }
   
   void CreateGraphic()
   {
      CreateOrChangeLine(m_xaName, m_xatt, m_xPnt.m_time, m_xPnt.m_price, m_aPnt.m_time, m_aPnt.m_price, m_color);
      CreateOrChangeLine(m_abName, m_abtt, m_aPnt.m_time, m_aPnt.m_price, m_bPnt.m_time, m_bPnt.m_price, m_color);
      CreateOrChangeLine(m_bcName, m_bctt, m_bPnt.m_time, m_bPnt.m_price, m_cPnt.m_time, m_cPnt.m_price, m_color);
      CreateOrChangeLine(m_cdName, m_cdtt, m_cPnt.m_time, m_cPnt.m_price, m_dPnt.m_time, m_dPnt.m_price, m_color);
      CreateOrChangeLine(m_xbName, m_xbtt, m_xPnt.m_time, m_xPnt.m_price, m_bPnt.m_time, m_bPnt.m_price, clrDarkGray, true);
      CreateOrChangeLine(m_xbName, m_xbtt, m_xPnt.m_time, m_xPnt.m_price, m_dPnt.m_time, m_dPnt.m_price, clrDarkGray, true);
      CreateOrChangeLine(m_bdName, m_bdtt, m_bPnt.m_time, m_bPnt.m_price, m_dPnt.m_time, m_dPnt.m_price, clrDarkGray, true);
   }
   
private:
   void CreateOrChangeLine(string name, string tooltip, datetime t1, double y1, datetime t2, double y2, uint clr, bool isDot=false)
   {
      long width = isDot ? 1:3;
      long chartId = ChartID();
      if(ObjectFind(chartId, name ) < 0 )
      {
         // if (!ObjectCreate( chartId, name, OBJ_HLINE, 0, 0, price))
         if (!ObjectCreate( chartId, name, OBJ_TREND, 0, t1, y1, t2, y2))
         {
            PrintFormat("ObjectCreate(%s, HLINE) [1] failed: %d", name, GetLastError() );
         }
         else if (!ObjectSetInteger( 0, name, OBJPROP_COLOR, clr )) 
         {
            PrintFormat("ObjectSetInteger(%s, Color) [2] failed: %d", name, GetLastError() );
         }
         else if (!ObjectSetInteger( 0, name, OBJPROP_WIDTH, width)) 
         {
            PrintFormat("ObjectSetInteger(%s, Width) [3] failed: %d", name, GetLastError() );
         }
         else if (!ObjectSetString( 0, name, OBJPROP_TOOLTIP, tooltip)) 
         {
            PrintFormat("ObjectSetInteger(%s, Width) [3] failed: %d", name, GetLastError() );
         }
         
      }
      else if(!ObjectMove(chartId, name, 0, t1, y1) || !ObjectMove(chartId, name, 1, t2, y2))
      {
         PrintFormat("ObjectMove(%s, OBJ_HLINE) [4] failed: %d", name, GetLastError() );
      }
      
      if(isDot)
      {
         ObjectSetInteger(chartId, name, OBJPROP_STYLE, STYLE_DOT);
      }
   }

   
};

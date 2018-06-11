//+------------------------------------------------------------------+
//|                                                 ThriftClient.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <FXMind\ClassRow.mqh>
#include <FXMind\FXMindClient.mqh>
#include <FXMind\TradeMethods.mqh>
#include <FXMind\TradePanel.mqh>

class TradePanel;
//+------------------------------------------------------------------+
//| класс OrderPanel  	                                             |
//+------------------------------------------------------------------+
class OrderPanel 
{
protected:
   bool              on_event;   // флаг обработки событий

   long              Y_hide;          // величина сдвига окна
   long              Y_obj;           // величина сдвига окна
   long              H_obj;           // величина сдвига окна
   void              SetXY(int m_corner);// Метод расчёта координат
   TradeMethods*     methods;
   TradePanel*       panel;
   Order*            order;   
public:
   int               w_corner;   // угол привязки
   int               w_xdelta;   // вертикальный отступ
   int               w_ydelta;   // горизонтальный отступ
   int               w_xpos;     // координата X точки привязки
   int               w_ypos;     // координата Y точки привязки
   int               w_bsize;    // ширина окна
   int               w_hsize;    // высота окна
   int               w_h_corner; // угол привязки HIDE режима
   WinCell           Property;   // свойства окна

   //---
   CRowType1         strOrder;       
   CRowType3         strRole;       
   CRowType3         strTrail;      
   CRowType2         strLotChange;     
   CRowType5         strProfit;
   CRowType2         strExternOrder;         
   CRowType5         strApply;

   OrderPanel(Order* ord, TradePanel* pan, TradeMethods* metod)
   {
      methods = metod;
      panel =  pan;
      order = ord;
      
      Property.TextColor=clrWhite;
      Property.BGColor=clrSteelBlue;
      Property.BGEditColor=clrDimGray;
      Property.Corner=(ENUM_BASE_CORNER)panel.w_corner;
      Property.Corn=1;
      Property.H=panel.Property.H;
      
      on_event = false;
   }
   
   void ~OrderPanel() 
   {
   }

   void              Init();           // метод запуска главного модуля
   void              Hide();          // метод: свернуть окно
   virtual void      OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam);
   void              SetWin(int m_xdelta,
                             int m_ydelta,
                             int m_bsize,
                             int m_corner);
   void              Draw();
   void              ClosePanel();
   void              Apply();
   
};

void OrderPanel::Init()
{
   w_corner = panel.w_corner;
   Property.H = panel.Property.H;
   
   w_xdelta = panel.w_xdelta + panel.w_bsize + 4;
   w_ydelta = panel.w_ydelta;

   if (PanelSize == PanelNormal)
   {
      w_bsize = 600;
      SetWin(w_xdelta, w_ydelta, w_bsize, CORNER_LEFT_UPPER);
   } else if (PanelSize == PanelSmall)
            {
               w_bsize = 400;
               SetWin(w_xdelta, w_ydelta, w_bsize, CORNER_LEFT_UPPER);
            }

   strOrder.Property=Property;       
   strRole.Property=Property;       
   strTrail.Property=Property;      
   strLotChange.Property=Property;     
   strProfit.Property=Property;
   strExternOrder.Property = Property;         
   strApply.Property=Property;   
   
   if (order != NULL)
   {
      strRole.Edit.SetText(EnumToString(order.Role()));
      strTrail.Edit.SetText(EnumToString(order.TrailingType));
      strLotChange.Edit.SetText(DoubleToString(order.lots, 2));
   }
   strExternOrder.Edit.SetText("Type extern order ticket");
}



//+------------------------------------------------------------------+
//| Метод Draw                                            
//+------------------------------------------------------------------+
void OrderPanel::Draw()
{   
   int X,Y,B;
   X=w_xpos;
   Y=w_ypos;
   B=w_bsize;
   
   strOrder.Property = Property;
   strRole.Property=Property;       
   strTrail.Property=Property;      
   strLotChange.Property=Property;     
   strProfit.Property=Property;
   strExternOrder.Property = Property;         
   strApply.Property=Property;

   if (order != NULL)
   {
      strOrder.Draw("OrderProp0", X, Y, B, 0, StringFormat("#%d Properties", order.ticket));
      Y=Y+Property.H+DELTA; 
      strRole.Draw("RoleProp0", X, Y, B, 150, "Role");
      Y=Y+Property.H+DELTA;           
      strTrail.Draw("TrailProp0", X, Y, B, 150, "Trailing");
      Y=Y+Property.H+DELTA;
      strLotChange.Draw("LotChange0", X, Y, B, 150, "Lots");
      Y=Y+Property.H+DELTA;
      string profitString = StringFormat("%g DistancePt(%d)", DoubleToString(order.Profit(), Digits()), order.PriceDistanceInPoint());
      strProfit.Draw("Profit0", X, Y, B, 100, "Profit", profitString);
      Y=Y+Property.H+DELTA;
   } else {
      strOrder.Draw("OrderProp0", X, Y, B, 0, "Orders Properties");
      Y=Y+Property.H+DELTA;
   }
   
   strExternOrder.Draw("ExternOrder0", X, Y, B, 100, "Extern Order");
   Y=Y+Property.H+DELTA;
   strApply.Draw("Apply0", X, Y, B, 100, "", "Apply");
       
   ChartRedraw();
   on_event=true;   
}
//+------------------------------------------------------------------+
void OrderPanel::SetWin(int m_xdelta,
                  int m_ydelta,
                  int m_bsize,
                  int m_corner)
{
//---
   if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_UPPER) w_corner=m_corner;
   else
      if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_UPPER) w_corner=m_corner;
   else
      if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_LOWER) w_corner=CORNER_LEFT_UPPER;
   else
      if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_LOWER) w_corner=CORNER_RIGHT_UPPER;
   else
     {
      Print("Error setting the anchor corner = ",m_corner);
      w_corner=CORNER_LEFT_UPPER;
     }
   if(m_xdelta>=0)w_xdelta=m_xdelta;
   else
     {
      Print("The offset error X = ",m_xdelta);
      w_xdelta=0;
     }
   if(m_ydelta>=0)w_ydelta=m_ydelta;
   else
     {
      Print("The offset error Y = ",m_ydelta);
      w_ydelta=0;
     }
   if(m_bsize>0)
     w_bsize=m_bsize;
   
   Property.Corner=(ENUM_BASE_CORNER)w_corner;
   SetXY(w_corner);
}

//+------------------------------------------------------------------+
void OrderPanel::SetXY(int m_corner)
{
   if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_UPPER)
     {
      w_xpos=w_xdelta;
      w_ypos=w_ydelta;
      Property.Corn=1;
     }
   else
   if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_UPPER)
     {
      w_xpos=w_xdelta+w_bsize;
      w_ypos=w_ydelta;
      Property.Corn=-1;
     }
   else
   if((ENUM_BASE_CORNER)m_corner==CORNER_LEFT_LOWER)
     {
      w_xpos=w_xdelta;
      w_ypos=w_ydelta+w_hsize+Property.H;
      Property.Corn=1;
     }
   else
   if((ENUM_BASE_CORNER)m_corner==CORNER_RIGHT_LOWER)
     {
      w_xpos=w_xdelta+w_bsize;
      w_ypos=w_ydelta+w_hsize+Property.H;
      Property.Corn=-1;
     }
   else
     {
      Print("Error setting the anchor corner = ",m_corner);
      w_corner=CORNER_LEFT_UPPER;
      w_xpos=0;
      w_ypos=0;
      Property.Corn=1;
     }
//---
   if((ENUM_BASE_CORNER)w_corner==CORNER_LEFT_UPPER) w_h_corner=CORNER_LEFT_LOWER;
   if((ENUM_BASE_CORNER)w_corner==CORNER_LEFT_LOWER) w_h_corner=CORNER_LEFT_LOWER;
   if((ENUM_BASE_CORNER)w_corner==CORNER_RIGHT_UPPER) w_h_corner=CORNER_RIGHT_LOWER;
   if((ENUM_BASE_CORNER)w_corner==CORNER_RIGHT_LOWER) w_h_corner=CORNER_RIGHT_LOWER;
//---
}

void OrderPanel::ClosePanel()
{
   strOrder.Delete();
   strRole.Delete();
   strTrail.Delete();
   strLotChange.Delete();
   strProfit.Delete();
   strExternOrder.Delete();
   strApply.Delete();
   delete &this;
   panel.orderPanel = NULL;
   panel.SetForceRedraw();
   panel.Draw();
}

void OrderPanel::Apply(void)
{
   string externOrderText = strExternOrder.Edit.GetText();
   int externTicket = (int)StringToInteger(externOrderText);
   if (externTicket > 0)
   {
       methods.globalOrders.AddUpdateByTicket(externTicket);
       methods.thrift.set.AddOrderToList(externTicket);
       methods.SaveOrders(methods.thrift.set);
       ClosePanel();
       return;
   }
   if (order != NULL)
   {
      string trail = strTrail.Edit.GetText();
      order.TrailingType = panel.EnumValueFromString<ENUM_TRAILING>(panel.TrailStrings, trail, order.TrailingType);
      
      string role = strRole.Edit.GetText();
      order.SetRole(panel.EnumValueFromString<ENUM_ORDERROLE>(panel.RoleStrings, role, order.Role()));
      
      double newLot = StringToDouble(strLotChange.Edit.GetText());
      if ((order.lots != newLot) && (newLot > 0))
      {
          methods.CloseOrderPartially(order, newLot);
      }
   }
   ClosePanel();
}

void OrderPanel::OnEvent(const int id,
                             const long &lparam,
                             const double &dparam,
                             const string &sparam)
{
   if(on_event)
     {         
      //--- трансляция событий OnChartEvent
         strOrder.OnEvent(id,lparam,dparam,sparam);
         strRole.OnEvent(id,lparam,dparam,sparam);
         strTrail.OnEvent(id,lparam,dparam,sparam);
         strLotChange.OnEvent(id,lparam,dparam,sparam);
         strProfit.OnEvent(id,lparam,dparam,sparam);
         strExternOrder.OnEvent(id,lparam,dparam,sparam);
         strApply.OnEvent(id,lparam,dparam,sparam);
      
      //--- создание графического объекта
      /*if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CREATE)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW1] в редакторе Edit STR1
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_ENDEDIT
         && StringFind(sparam,".STR1",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW2] : кнопка Plus STR2
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR2",0)>0
         && StringFind(sparam,".Button3",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW2] : кнопка Minus STR2
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR2",0)>0
         && StringFind(sparam,".Button4",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Plus STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button3",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Minus STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button4",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Up STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button5",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- редактирование переменных [NEW3] : кнопка Down STR3
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR3",0)>0
         && StringFind(sparam,".Button6",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [new4] STR4
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR4",0)>0
         && StringFind(sparam,".Button",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [NEW5] STR5
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR5",0)>0
         && StringFind(sparam,"(1)",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [new5] STR5
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR5",0)>0
         && StringFind(sparam,"(2)",0)>0)
        {
         //--- реакция на планируемое событие
        }
      //--- нажатие кнопки [] STR5
      if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK
         && StringFind(sparam,".STR5",0)>0
         && StringFind(sparam,"(3)",0)>0)
        {
         //--- реакция на планируемое событие
        }
        */
        
        if((ENUM_CHART_EVENT)id==CHARTEVENT_OBJECT_CLICK)
        {
            //--- редактирование переменных [NEW3] : кнопка Plus STR3
            if( StringFind(sparam,".Button3",0)>0)
            {
               if (StringFind(sparam, strTrail.name) >= 0)
               {
                  string text = strTrail.Edit.GetText();
                  ENUM_TRAILING tr = panel.EnumValueFromString<ENUM_TRAILING>(panel.TrailStrings, text, order.TrailingType);
                  int i = (int)tr;
                  i++;
                  if (i < TRAILS_COUNT)
                     tr = (ENUM_TRAILING)i;
                  else 
                     tr = (ENUM_TRAILING)0;
                  strTrail.Edit.SetText(EnumToString(tr));   
                  Draw();                  
               }
                
               if (StringFind(sparam, strRole.name) >= 0)
               {
                  string text = strRole.Edit.GetText();
                  ENUM_ORDERROLE rol = panel.EnumValueFromString<ENUM_ORDERROLE>(panel.RoleStrings, text, order.Role());
                  int i = (int)rol;
                  i++;
                  if (i < ROLES_COUNT)
                     rol = (ENUM_ORDERROLE)i;
                  else 
                     rol = (ENUM_ORDERROLE)0;
                  strRole.Edit.SetText(EnumToString(rol));   
                  Draw();
               }
            }
            
            //--- редактирование переменных [NEW3] : кнопка Minus STR3
            if (StringFind(sparam,".Button4",0)>0)
            {
               if (StringFind(sparam, strTrail.name) >= 0)
               {
                  string text = strTrail.Edit.GetText();
                  ENUM_TRAILING tr = panel.EnumValueFromString<ENUM_TRAILING>(panel.TrailStrings, text, order.TrailingType);
                  int i = (int)tr;
                  i--;
                  if (i >= 0)
                     tr = (ENUM_TRAILING)i;
                  else 
                     tr = (ENUM_TRAILING)(TRAILS_COUNT - 1);
                  strTrail.Edit.SetText(EnumToString(tr));   
                  Draw();
               }
                
               if (StringFind(sparam, strRole.name) >= 0)
               {
                  string text = strRole.Edit.GetText();
                  ENUM_ORDERROLE rol = panel.EnumValueFromString<ENUM_ORDERROLE>(panel.RoleStrings, text, order.Role());
                  int i = (int)rol;
                  i--;
                  if (i >= 0)
                     rol = (ENUM_ORDERROLE)i;
                  else 
                     rol = (ENUM_ORDERROLE)(ROLES_COUNT - 1);
                  strRole.Edit.SetText(EnumToString(rol));   
                  Draw();
               }
            }
        
            if (StringFind(sparam, strApply.name) >= 0)
               Apply();
               
            if ((StringFind(sparam, strOrder.name) >= 0) &&
                 (StringFind(sparam,".Button1",0)>0))
            {
                ClosePanel();
            }
               
               
        }

     }
}


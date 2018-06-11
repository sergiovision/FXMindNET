#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <stdliberr.mqh>
#include <FXMind\Orders.mqh>
#include <FXMind\SettingsFile.mqh>
#include <FXMind\FXMindClient.mqh>


class TradeMethods 
{
protected:
    datetime sdtPrevtime;
    string   EANameString;
    color    TrailingColor;
            
   //+------------------------------------------------------------------+
   bool CloseOrder(int ticket, double lots, double price, color arrow_color)
   {
      price = NormalizeDouble(price, Digits());
      int err = ::GetLastError();
      err = 0;
      bool result = false;
      bool exit_loop = false;
      int cnt = 0;
      while (!exit_loop)
      {
         if (Utils.SelectOrder(ticket))
         {
            lots = NormalizeDouble(lots, 2);
            price = NormalizeDouble(price, Digits());
            if (Utils.OrderLots() > lots)
               result = Utils._OrderClosePartially(ticket, lots, price, Slippage);
            else
               result = Utils._OrderClose(ticket, lots, price, Slippage, arrow_color);
            if (result == true) 
            {  
            
               if (!Utils.IsTesting())
               {
                  Sleep(100);
               }
               return true;        
            } 
            err = ::GetLastError();
            switch (err)
            {
               case ERR_NO_ERROR:
                  exit_loop = true;
               break;
               case ERR_SERVER_BUSY:
               case ERR_BROKER_BUSY:
               case ERR_TRADE_CONTEXT_BUSY:
               case ERR_TRADE_SEND_FAILED:
                  cnt++;
               break;
               case ERR_INVALID_PRICE:
               case ERR_PRICE_CHANGED:
               case ERR_OFF_QUOTES:
               case ERR_REQUOTE:
                  Utils.RefreshRates();
                  continue;
               break;
               default:
                exit_loop = true;
            }
            if (cnt > RetryOnErrorNumber )
               exit_loop = true;
            
            if ( !exit_loop )
            {
               if (!Utils.IsTesting())
                  Sleep(SLEEP_DELAY_MSEC);
               Utils.RefreshRates();
            }
            else 
            {
               if (err != ERR_NO_ERROR) 
               {
                  LogError(StringFormat("^^^^^^^^^^Error Close Order ticket: %d, error#: %d", ticket ,err));
               }
            }
         }
      }
      return result;
   }
   //+------------------------------------------------------------------+

 
public:
   OrderSelection globalOrders;
   FXMindClient *thrift;
   string Symbol;
   double Point;
   int Digits;
   
   TradeMethods(FXMindClient* th, string eaname) 
      :globalOrders(MaxOpenedTrades)
   {
       thrift = th;
       sdtPrevtime = 0;
       EANameString = eaname;
       
       TrailingColor = Yellow;  
       Symbol = Symbol();
       Point = Point();
       Digits = Digits();
   }
      
   ~TradeMethods()
   {
      globalOrders.Clear();
   }
   
   
   void SaveOrders(SettingsFile *set)
   {
      OrderSelection* orders = GetOpenOrders(set);
      string orderSection = "";
      string ActiveOrdersList = "";
      //int size = orders.Total();
      //int i = 0;
      FOREACH_ORDER(orders)
      {
         orderSection = order.OrderSection();
         //Print("Save Order: "+ orderSection);
         set.SetParam(orderSection, "ticket", order.ticket);
         //set.SetParam(orderSection, "symbol", order.symbol);
         set.SetParam(orderSection, "openPrice", order.openPrice);
         set.SetParam(orderSection, "role", order.Role());
         set.SetParam(orderSection, "TrailingType", order.TrailingType);
         set.SetParam(orderSection, "stopLoss", order.stopLoss);
         set.SetParam(orderSection, "takeProfit", order.takeProfit);
         //set.SetParam(orderSection, "comment", order.comment);
         ActiveOrdersList += orderSection;
         //if (i++ < (size - 1 ))
         ActiveOrdersList += "|"; 
      }
      ActiveOrdersList += thrift.constant.GLOBAL_SECTION_NAME;
      thrift.SaveAllSettings(ActiveOrdersList);
   }
   
   void LoadOrders(SettingsFile *set)
   {
      OrderSelection* orders = GetOpenOrders(set);
      
      FOREACH_ORDER(orders)
      {
         LoadOrder(order, set);
      }
   }   
   
   void LoadOrder(Order* order, SettingsFile* set)
   {
      string orderSection = order.OrderSection();
      set.GetIniKey(orderSection, "ticket", order.ticket);
      set.GetIniKey(orderSection, "openPrice", order.openPrice);
      int role = 0;
      set.GetIniKey(orderSection, "role", role);
      order.SetRole((ENUM_ORDERROLE)role);
      int tt = 0;
      set.GetIniKey(orderSection, "TrailingType", tt);
      order.TrailingType = (ENUM_TRAILING)tt;
      set.GetIniKey(orderSection, "stopLoss", order.stopLoss);
      set.GetIniKey(orderSection, "takeProfit", order.takeProfit);
      if (!Utils.IsTesting())
         Print(StringFormat("Order %d restored successfully ", order.ticket));
   }

   //+------------------------------------------------------------------+
   void LogInfo(string message)
   {
       Print(message);
   }
   
   void LogError(string message)
   {
       Comment(message);
   }
   
   double RiskAmount(double percent)
   {
      return Utils.AccountBalance()*percent;
   }
   
   OrderSelection* GetOpenOrders(SettingsFile* set)
   {
      //if (IsTesting())
      //   Print("GetOpenOrders start");
      
      globalOrders.MarkOrdersAsDirty();
      int ticket = 0;
      string _symbol = Symbol();
      for (int i = Utils.OrdersTotal() - 1; i >= 0; i-- )
      {     
         if (Utils.SelectOrderByPos(i))
         {
            ticket = Utils.OrderTicket();
            if ((thrift.MagicNumber == Utils.OrderMagicNumber()) && (_symbol == Utils.OrderSymbol()))
            {
               globalOrders.AddUpdateByTicket(ticket);
            } else if (set.IsTicketExistToLoad(ticket))
                   {
                      globalOrders.AddUpdateByTicket(ticket);
                   }
    
         }
      }
      
      globalOrders.RemoveDirtyObsoleteOrders();
      /*
      FOREACH_ORDER(globalOrders)
      {
         if (order.bDirty)
         {         
            set.DeleteSection(order.OrderSection());
            globalOrders.DeleteCurrent();
         }
      }    
      globalOrders.Sort();  
      */
      //if (IsTesting())
      //   Print(StringFormat("GetOpenOrders end: return %d orders", globalOrders.Total()));

      return &globalOrders;
   }
        
   //+------------------------------------------------------------------+
   int CountOrdersByType(int op_type, OrderSelection& orders) 
   {
      int count = 0;
      FOREACH_ORDER(orders)
      {
         if (order.type == op_type)
             count++;
      }
      return(count);
   }
   
   //+------------------------------------------------------------------+
   int CountOrdersByRole(ENUM_ORDERROLE role, OrderSelection& orders) 
   {
      int count = 0;
      FOREACH_ORDER(orders)
      {
         if (order.Role() == role)
             count++;
      }
      return(count);
   }
   
   Order* FindGridHead(OrderSelection& orders, int& count) 
   {
      Order* head = NULL;
      count = 0;
      FOREACH_ORDER(orders)
      {
         if (order.Role() == GridHead)
             head = order;
         if (order.isGridOrder())
             count++;
      }
      return head;
   }
         
   int GetGridStepValue()
   {
      int realGridStep = MathMax(CalculateCurrentGridStep(), actualGridStep);
        return realGridStep;
   }
   
   int CalculateCurrentGridStep()
   {
      return (int)double(Utils.iATR(PERIOD_D1,14, 0)/Point()); 
   }

   //+------------------------------------------------------------------+
   double GetGridProfit(OrderSelection& orders) 
   {
      int count = 0;
      double gridprofit = 0;
      FOREACH_ORDER(orders)
      {
         if (order.isGridOrder() && order.Select())
             gridprofit += order.RealProfit();
      }
      return gridprofit;
   }
   //+------------------------------------------------------------------+
   double GetProfit(OrderSelection& orders) 
   {
      int count = 0;
      double profit = 0;
      FOREACH_ORDER(orders)
      {
          profit += order.RealProfit();
      }
      return profit;
   }
   
   //+------------------------------------------------------------------+
   void CloseGrid() 
   {
      // CLOSE ALL GRID ORDERS
      Print(StringFormat("++++++++++Close Grid(%d):++++++++++", globalOrders.Total()));
      FOREACH_ORDER(globalOrders)
      {
         if (order.isGridOrder())
         {
            if (CloseOrder(order, clrMediumSpringGreen))
            {
               Print(StringFormat("CLOSED GRID item: %s", order.ToString()));
               globalOrders.DeleteCurrent();
            }
         }
      }
      globalOrders.Sort();
      
      
   }
   
   //+------------------------------------------------------------------+
   int CountAllTrades() //OrderSelection* orders
   {
       return globalOrders.Total();
   }
   
   //+------------------------------------------------------------------+
   Order* OpenOrder(Order& order) 
   {
       if (CountAllTrades() >= MaxOpenedTrades)
       {
          LogInfo(StringFormat("Reached maximum of orders! %d. No new orders!", MaxOpenedTrades));
          delete &order;
          return NULL;
       }
       if ((AllowBUY == false)&& (order.type==OP_BUY))
       {
          delete &order;
          LogInfo("BUY Orders are not allowed");
          return NULL; 
       }
       if ((AllowSELL == false)&& (order.type==OP_SELL))
       {
          delete &order;
          LogInfo("SELL Orders are not allowed");
          return NULL; 
       }
       order.comment = EANameString;        
       order.magic = thrift.MagicNumber;  
       order.symbol = Symbol;
       if (Utils.OpenOrder(order, Slippage))
       {
          if (order.Select())
          {
             globalOrders.Fill(order);
             globalOrders.Add(&order);
             if (!Utils.IsTesting())
               SaveOrders(thrift.set);
             return &order;
          }
      }
      return NULL;
   }

   //+------------------------------------------------------------------+
   bool ChangeOrder(Order& order, double stoploss, double takeprofit, datetime expiration, color arrow_color)
   {
      if (!order.NeedChanges(stoploss, takeprofit, expiration))
      {
         LogInfo(StringFormat("ChangeOrder: No need changes", order.ticket));
         return false;
      }
      bool result = false;
      int err = ::GetLastError();
      err = 0;
      bool exit_loop = false;
      int cnt = 0;
      while (!exit_loop)
      {
         if (order.Select())
         {
            order.stopLoss = NormalizeDouble(stoploss, Digits());
            order.takeProfit = NormalizeDouble(takeprofit, Digits());
            order.expiration = expiration;
            
            //order.PrintIfWrong("ChangeOrder");
            
            result = Utils._OrderModify(order.ticket,Utils.OrderOpenPrice(), order.stopLoss, order.takeProfit, order.expiration, arrow_color);
            if (result == true)
               return true;
            err = ::GetLastError();
            switch (err)
            {
               case ERR_NO_ERROR:
                  exit_loop = true;
               break;
               case ERR_NO_RESULT:
                  return true;
               case ERR_SERVER_BUSY:
               case ERR_BROKER_BUSY:
               case ERR_TRADE_CONTEXT_BUSY:
               case ERR_TRADE_SEND_FAILED:
                  cnt++;
               break;
               case ERR_INVALID_PRICE:
               case ERR_PRICE_CHANGED:
               case ERR_OFF_QUOTES:
               case ERR_REQUOTE:
                  Sleep(SLEEP_DELAY_MSEC);
                  Utils.RefreshRates();
                  continue;
               break;
               default:
                exit_loop = true;
            }
            if (cnt > RetryOnErrorNumber )
               exit_loop = true;
            
            if ( !exit_loop )
            {
               if (!Utils.IsTesting())
                  Sleep(SLEEP_DELAY_MSEC);
               Utils.RefreshRates();
            }
            else 
            {
               if (err != ERR_NO_ERROR) 
               {
                  LogError(StringFormat("^^^^^^^^^^Error OrderModify ticket: %d, error#: %d ", order.ticket, err));
               }
            }
         }
      }

       if (result)
       {
          globalOrders.Fill(order);
          //order.openPrice = price;
          //order.stopLoss = stoploss;
          //order.takeProfit = takeprofit;
          //order.expiration = expiration;
       }
       return result;
   }

   bool CloseOrder(Order& order, color cor) 
   {
      order.MarkToClose();
      if (OP_BUY == order.type)
         order.closePrice = Utils.Bid();
      else 
         order.closePrice = Utils.Ask();
      bool result = CloseOrder(order.ticket, order.lots, order.closePrice, cor); 
      //if (result && bRemoveOrder) {
      //    LogInfo(StringFormat("****CLOSED Order", order.ticket));
      //    globalOrders.DeleteByTicket(order.ticket);
      //}
      return result;
   }
   
   int CloseOrderPartially(Order& order, double newLotSize)
   {
      double lots = order.lots;
      double partLot = NormalizeDouble(newLotSize, 2);
      if (lots > partLot)
         partLot = NormalizeDouble(lots/2.0,2);
      double closePrice = 0;
      if (OP_BUY == order.type)
      {
         closePrice = Utils.Bid();
      }
      else
      {
         closePrice = Utils.Ask();
      }
      if (CloseOrder(order.ticket, partLot, closePrice, Yellow))
      {
         int newticket = searchNewTicket(order.ticket);
         order.ticket = newticket;
         return newticket;
      } else
        return -1;
   }
   
   int searchNewTicket(int oldTicket)
   {
      for(int i=Utils.OrdersTotal()-1; i>=0; i--)
         if(Utils.SelectOrderByPos(i) &&
            StringToInteger(StringSubstr(Utils.OrderComment(),StringFind(Utils.OrderComment(),"#")+1)) == oldTicket )
            return (Utils.OrderTicket());
      return (-1);
   }


   
//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ФРАКТАЛАМ                                            |
//| Функции передаётся тикет позиции, количество баров в фрактале,   |
//| и отступ (пунктов) - расстояние от макс. (мин.) свечи, на        |
//| которое переносится стоплосс (от 0), trlinloss - тралить ли в    |
//| зоне убытков                                                     |
//+------------------------------------------------------------------+
void TrailingByFractals(Order& order,int tmfrm,int frktl_bars,int indent,bool trlinloss)
   {
   int i, z; // counters
   int extr_n; // номер ближайшего экстремума frktl_bars-барного фрактала 
   double temp; // служебная переменная
   int after_x, be4_x; // свечей после и до пика соответственно
   int ok_be4, ok_after; // флаги соответствия условию (1 - неправильно, 0 - правильно)
   int sell_peak_n = 0, buy_peak_n = 0; // номера экстремумов ближайших фракталов на продажу (для поджатия дл.поз.) и покупку соответсвенно   
   
   // проверяем переданные значения
   if ((frktl_bars<=3) || (indent<0) || (!order.Valid()) || ((tmfrm!=1) && (tmfrm!=5) && (tmfrm!=15) && (tmfrm!=30) && (tmfrm!=60) && (tmfrm!=240) && (tmfrm!=1440) && (tmfrm!=10080) && (tmfrm!=43200)) || (!order.Select()))
   {
      Print("Трейлинг функцией TrailingByFractals() невозможен из-за некорректности значений переданных ей аргументов.");
      return ;
   } 
   
   temp = frktl_bars;
      
   if (MathMod(frktl_bars,2)==0)
   extr_n = (int)temp/2;
   else                
   extr_n = (int)MathRound(temp/2);
      
   // баров до и после экстремума фрактала
   after_x = frktl_bars - extr_n;
   if (MathMod(frktl_bars,2)!=0)
   be4_x = frktl_bars - extr_n;
   else
   be4_x = frktl_bars - extr_n - 1;    
   
   // если длинная позиция (OP_BUY), находим ближайший фрактал на продажу (т.е. экстремум "вниз")
   if (Utils.OrderType()==OP_BUY)
      {
      // находим последний фрактал на продажу
      for (i=extr_n;i<iBars(Symbol(),tmfrm);i++)
         {
         ok_be4 = 0; ok_after = 0;
         
         for (z=1;z<=be4_x;z++)
            {
            if (iLow(Symbol(),tmfrm,i)>=iLow(Symbol(),tmfrm,i-z)) 
               {
               ok_be4 = 1;
               break;
               }
            }
            
         for (z=1;z<=after_x;z++)
            {
            if (iLow(Symbol(),tmfrm,i)>iLow(Symbol(),tmfrm,i+z)) 
               {
               ok_after = 1;
               break;
               }
            }            
         
         if ((ok_be4==0) && (ok_after==0))                
            {
            sell_peak_n = i; 
            break;
            }
         }
     
      // если тралить в убытке
      if (trlinloss==true)
         {
         // если новый стоплосс лучше имеющегося (в т.ч. если стоплосс == 0, не выставлен)
         // а также если курс не слишком близко, ну и если стоплосс уже не был перемещен на рассматриваемый уровень         
         if ((iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point()>Utils.OrderStopLoss()) && (iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point()<Utils.Bid() - Utils.StopLevelPoints()))
            {
               ChangeOrder(order,iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point(),Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            //if (!OrderModify(ticket,Utils.OrderOpenPrice(),iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration()))
            //Print("Не удалось модифицировать стоплосс ордера №",OrderTicket(),". Ошибка: ",GetLastError());
            }
         }
      // если тралить только в профите, то
      else
         {
            // если новый стоплосс лучше имеющегося И курса открытия, а также не слишком близко к текущему курсу
            if ((iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point()>Utils.OrderStopLoss()) && (iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point()>Utils.OrderOpenPrice()) && (iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point()<Utils.Bid()-Utils.StopLevelPoints()))
            {
               ChangeOrder(order,iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
               //if (!OrderModify(ticket,Utils.OrderOpenPrice(),iLow(Symbol(),tmfrm,sell_peak_n)-indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration()))
               //Print("Не удалось модифицировать стоплосс ордера №",OrderTicket(),". Ошибка: ",GetLastError());
            }
         }
      }
      
   // если короткая позиция (OP_SELL), находим ближайший фрактал на покупку (т.е. экстремум "вверх")
   if (Utils.OrderType()==OP_SELL)
      {
      // находим последний фрактал на продажу
      for (i=extr_n;i<iBars(Symbol(),tmfrm);i++)
         {
         ok_be4 = 0; ok_after = 0;
         
         for (z=1;z<=be4_x;z++)
            {
            if (iHigh(Symbol(),tmfrm,i)<=iHigh(Symbol(),tmfrm,i-z)) 
               {
               ok_be4 = 1;
               break;
               }
            }
            
         for (z=1;z<=after_x;z++)
            {
            if (iHigh(Symbol(),tmfrm,i)<iHigh(Symbol(),tmfrm,i+z)) 
               {
               ok_after = 1;
               break;
               }
            }            
         
         if ((ok_be4==0) && (ok_after==0))                
            {
            buy_peak_n = i;
            break;
            }
         }        
      
      // если тралить в убытке
      if (trlinloss==true)
         {
         if (((iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point()<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && (iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point()>Utils.Ask()+Utils.StopLevelPoints()))
            {
               ChangeOrder(order,iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }      
      // если тралить только в профите, то
      else
         {
         // если новый стоплосс лучше имеющегося И курса открытия
         if ((((iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0))) && (iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point<Utils.OrderOpenPrice()) && (iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point>Utils.Ask()+Utils.StopLevelPoints()))
            {
                ChangeOrder(order,iHigh(Symbol(),tmfrm,buy_peak_n)+(indent+Utils.Spread())*Point(),Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ТЕНЯМ N СВЕЧЕЙ                                       |
//| Функции передаётся тикет позиции, количество баров, по теням     |
//| которых необходимо трейлинговать (от 1 и больше) и отступ        |
//| (пунктов) - расстояние от макс. (мин.) свечи, на которое         |
//| переносится стоплосс (от 0), trlinloss - тралить ли в лоссе      | 
//+------------------------------------------------------------------+
void TrailingByShadows(Order& order,int tmfrm,int bars_n, int indent,bool trlinloss)
   {  
   
   int i; // counter
   double new_extremum = 0;
   
   // проверяем переданные значения
   if ((bars_n<1) || (indent<0) || (!order.Valid()) || ((tmfrm!=1) && (tmfrm!=5) && (tmfrm!=15) && (tmfrm!=30) && (tmfrm!=60) && (tmfrm!=240) && (tmfrm!=1440) && (tmfrm!=10080) && (tmfrm!=43200)) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingByShadows() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   // если длинная позиция (OP_BUY), находим минимум bars_n свечей
   if (Utils.OrderType()==OP_BUY)
      {
      for(i=1;i<=bars_n;i++)
         {
         if (i==1) new_extremum = iLow(Symbol(),tmfrm,i);
         else 
         if (new_extremum>iLow(Symbol(),tmfrm,i)) new_extremum = iLow(Symbol(),tmfrm,i);
         }         
      
      // если тралим и в зоне убытков
      if (trlinloss == true)
         {
           // если найденное значение "лучше" текущего стоплосса позиции, переносим 
           if ((((new_extremum - indent*Point)>Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && (new_extremum - indent*Point<Utils.Bid()-Utils.StopLevelPoints()))
              ChangeOrder(order, new_extremum - indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      else
         {
           // если новый стоплосс не только лучше предыдущего, но и курса открытия позиции
           if ((((new_extremum - indent*Point)>Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && ((new_extremum - indent*Point)>Utils.OrderOpenPrice()) && (new_extremum - indent*Point<Utils.Bid()-Utils.StopLevelPoints()))
              ChangeOrder(order, new_extremum-indent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
      
   // если короткая позиция (OP_SELL), находим минимум bars_n свечей
   if (Utils.OrderType()==OP_SELL)
      {
      for(i=1;i<=bars_n;i++)
         {
         if (i==1) new_extremum = iHigh(Symbol(),tmfrm,i);
         else 
         if (new_extremum<iHigh(Symbol(),tmfrm,i)) new_extremum = iHigh(Symbol(),tmfrm,i);
         }         
           
      // если тралим и в зоне убытков
      if (trlinloss==true)
         {
         // если найденное значение "лучше" текущего стоплосса позиции, переносим 
            if ((((new_extremum + (indent + Utils.Spread())*Point)<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && (new_extremum + (indent + Utils.Spread())*Point>Utils.Ask()+Utils.StopLevelPoints()))
                ChangeOrder(order, new_extremum + (indent + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      else
         {
         // если новый стоплосс не только лучше предыдущего, но и курса открытия позиции
             if ((((new_extremum + (indent + Utils.Spread())*Point)<Utils.OrderStopLoss()) || (Utils.OrderStopLoss()==0)) && ((new_extremum + (indent + Utils.Spread())*Point)<Utils.OrderOpenPrice()) && (new_extremum + (indent +  Utils.Spread())*Point>Utils.Ask()+Utils.StopLevelPoints()))
                ChangeOrder(order, new_extremum + (indent + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }      
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ СТАНДАРТНЫЙ-СТУПЕНЧАСТЫЙ                                |
//| Функции передаётся тикет позиции, расстояние от курса открытия,  |
//| на котором трейлинг запускается (пунктов) и "шаг", с которым он  |
//| переносится (пунктов)                                            |
//| Пример: при +30 стоп на +10, при +40 - стоп на +20 и т.д.        |
//+------------------------------------------------------------------+

void TrailingStairs(Order& order,int trldistance,int trlstep)
   { 
   
   double nextstair; // ближайшее значение курса, при котором будем менять стоплосс

   // проверяем переданные значения
   if ((trldistance<Utils.StopLevel()) || (trlstep<1) || (trldistance<trlstep) || (!order.Valid()) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingStairs() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
      // расчитываем, при каком значении курса следует скорректировать стоплосс
      // если стоплосс ниже открытия или равен 0 (не выставлен), то ближайший уровень = курс открытия + trldistance + спрэд
      if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice()))
      nextstair =Utils.OrderOpenPrice() + trldistance*Point;
         
      // иначе ближайший уровень = текущий стоплосс + trldistance + trlstep + спрэд
      else
      nextstair =Utils.OrderStopLoss() + trldistance*Point;

      // если текущий курс (Bid) >= nextstair и новый стоплосс точно лучше текущего, корректируем последний
      if (Utils.Bid()>=nextstair)
         {
            if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice())) && ((Utils.OrderOpenPrice() + trlstep*Point) < (Utils.Bid()-Utils.StopLevelPoints()))) 
            {
               ChangeOrder(order,Utils.OrderOpenPrice() + trlstep*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      else
         {
            ChangeOrder(order,Utils.OrderStopLoss() + trlstep*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      { 
      // расчитываем, при каком значении курса следует скорректировать стоплосс
      // если стоплосс ниже открытия или равен 0 (не выставлен), то ближайший уровень = курс открытия + trldistance + спрэд
      if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice()))
      nextstair =Utils.OrderOpenPrice() - (trldistance + Utils.Spread())*Point;
      
      // иначе ближайший уровень = текущий стоплосс + trldistance + trlstep + спрэд
      else
      nextstair =Utils.OrderStopLoss() - (trldistance + Utils.Spread())*Point;
       
      // если текущий курс (Аск) >= nextstair и новый стоплосс точно лучше текущего, корректируем последний
      if (Utils.Ask()<=nextstair)
         {
         if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice())) && ((Utils.OrderOpenPrice() - (trlstep + Utils.Spread())*Point) > (Utils.Ask()+Utils.StopLevelPoints())))
            {
                ChangeOrder(order,Utils.OrderOpenPrice() - (trlstep + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      else
         {
             ChangeOrder(order,Utils.OrderStopLoss()- (trlstep + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ СТАНДАРТНЫЙ-ЗАТЯГИВАЮЩИЙСЯ                              |
//| Функции передаётся тикет позиции, исходный трейлинг (пунктов) и  |
//| 2 "уровня" (значения профита, пунктов), при которых трейлинг     |
//| сокращаем, и соответствующие значения трейлинга (пунктов)        |
//| Пример: исходный трейлинг 30 п., при +50 - 20 п., +80 и больше - |
//| на расстоянии в 10 пунктов.                                      |
//+------------------------------------------------------------------+

void TrailingUdavka(Order& order,int trl_dist_1,int level_1,int trl_dist_2,int level_2,int trl_dist_3)
   {  
   
   double newstop = 0; // новый стоплосс
   double trldist = 0; // расстояние трейлинга (в зависимости от "пройденного" может = trl_dist_1, trl_dist_2 или trl_dist_3)

   // проверяем переданные значения
   if ((trl_dist_1<Utils.StopLevel()) || (trl_dist_2<Utils.StopLevel()) || (trl_dist_3<Utils.StopLevel()) || 
   (level_1<=trl_dist_1) || (level_2<=trl_dist_1) || (level_2<=level_1) || (!order.Valid()) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingUdavka() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
        double bid = Utils.Bid();
      // если профит <=trl_dist_1, то trldist=trl_dist_1, если профит>trl_dist_1 && профит<=level_1*Point ...
      if ((bid-Utils.OrderOpenPrice())<=level_1*Point) trldist = trl_dist_1;
      if (((bid-Utils.OrderOpenPrice())>level_1*Point) && ((Utils.Bid()-Utils.OrderOpenPrice())<=level_2*Point)) trldist = trl_dist_2;
      if ((bid-Utils.OrderOpenPrice())>level_2*Point) trldist = trl_dist_3; 
            
      // если стоплосс = 0 или меньше курса открытия, то если тек.цена (Bid) больше/равна дистанции курс_открытия+расст.трейлинга
      if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice()))
         {
         if (bid>(Utils.OrderOpenPrice() + trldist*Point))
         newstop = bid -  trldist*Point;
         }

      // иначе: если текущая цена (Bid) больше/равна дистанции текущий_стоплосс+расстояние трейлинга, 
      else
         {
         if (bid>(Utils.OrderStopLoss() + trldist*Point))
         newstop = bid -  trldist*Point;
         }
      
      // модифицируем стоплосс
      if ((newstop>Utils.OrderStopLoss()) && (newstop<bid-Utils.StopLevelPoints()))
         {
            ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      { 
         double ask = Utils.Ask();

      // если профит <=trl_dist_1, то trldist=trl_dist_1, если профит>trl_dist_1 && профит<=level_1*Point ...
      if ((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))<=level_1*Point) trldist = trl_dist_1;
      if (((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))>level_1*Point) && ((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))<=level_2*Point)) trldist = trl_dist_2;
      if ((Utils.OrderOpenPrice()-(ask + Utils.Spread()*Point))>level_2*Point) trldist = trl_dist_3; 
            
      // если стоплосс = 0 или меньше курса открытия, то если тек.цена (Ask) больше/равна дистанции курс_открытия+расст.трейлинга
      if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice()))
         {
         if (ask<(Utils.OrderOpenPrice() - (trldist + Utils.Spread())*Point))
         newstop = ask + trldist*Point;
         }

      // иначе: если текущая цена (Bid) больше/равна дистанции текущий_стоплосс+расстояние трейлинга, 
      else
         {
         if (ask<(Utils.OrderStopLoss() - (trldist + Utils.Spread())*Point))
         newstop = ask +  trldist*Point;
         }
            
       // модифицируем стоплосс
      if (newstop>0)
         {
         if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice())) && (newstop>ask+Utils.StopLevelPoints()))
            {
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         else
            {
            if ((newstop<Utils.OrderStopLoss()) && (newstop>Utils.Ask()+Utils.StopLevelPoints()))  
               {
                  ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
               }
            }
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ВРЕМЕНИ                                              |
//| Функции передаётся тикет позиции, интервал (минут), с которым,   |
//| передвигается стоплосс и шаг трейлинга (на сколько пунктов       |
//| перемещается стоплосс, trlinloss - тралим ли в убытке            |
//| (т.е. с определённым интервалом подтягиваем стоп до курса        |
//| открытия, а потом и в профите, либо только в профите)            |
//+------------------------------------------------------------------+
void TrailingByTime(Order &order,int interval,int trlstep,bool trlinloss)
   {
      
   // проверяем переданные значения
   if ((!order.Valid()) || (interval<1) || (trlstep<1) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingByTime() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      }
      
   double minpast; // кол-во полных минут от открытия позиции до текущего момента 
   double times2change; // кол-во интервалов interval с момента открытия позиции (т.е. сколько раз должен был быть перемещен стоплосс) 
   double newstop; // новое значение стоплосса (учитывая кол-во переносов, которые должны были иметь место)
   
   // определяем, сколько времени прошло с момента открытия позиции
   minpast = (double)(TimeCurrent() - Utils.OrderOpenTime()) / 60;
      
   // сколько раз нужно было передвинуть стоплосс
   times2change = MathFloor(minpast / interval);
         
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
      // если тралим в убытке, то отступаем от стоплосса (если он не 0, если 0 - от открытия)
      if (trlinloss==true)
         {
         if (Utils.OrderStopLoss()==0) newstop =Utils.OrderOpenPrice() + times2change*(trlstep*Point);
         else newstop =Utils.OrderStopLoss() + times2change*(trlstep*Point); 
         }
      else
      // иначе - от курса открытия позиции
      newstop =Utils.OrderOpenPrice() + times2change*(trlstep*Point); 
         
      if (times2change>0)
         {
         if ((newstop>Utils.OrderStopLoss()) && (newstop<Utils.Bid()- Utils.StopLevelPoints()))
            {
                ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      {
      // если тралим в убытке, то отступаем от стоплосса (если он не 0, если 0 - от открытия)
      if (trlinloss==true)
         {
         if (Utils.OrderStopLoss()==0) newstop =Utils.OrderOpenPrice() - times2change*(trlstep*Point) - Utils.Spread()*Point;
         else newstop =Utils.OrderStopLoss() - times2change*(trlstep*Point) - Utils.Spread()*Point;
         }
      else
      newstop =Utils.OrderOpenPrice() - times2change*(trlstep*Point) - Utils.Spread()*Point;
                
      if (times2change>0)
         {
         if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice())) && (newstop>Utils.Ask()+Utils.StopLevelPoints()))
            {
                ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         else
         if ((newstop<Utils.OrderStopLoss()) && (newstop>Utils.Ask()+Utils.StopLevelPoints()))
            {
                ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ATR (Average True Range, Средний истинный диапазон)  |
//| Функции передаётся тикет позиции, период АТR и коэффициент, на   |
//| который умножается ATR. Т.о. стоплосс "тянется" на расстоянии    |
//| ATR х N от текущего курса; перенос - на новом баре (т.е. от цены |
//| открытия очередного бара)                                        |
//+------------------------------------------------------------------+
void TrailingByATR(Order& order,int atr_timeframe,int atr1_period,int atr1_shift,int atr2_period,int atr2_shift,double coeff,bool trlinloss)
   {
   // проверяем переданные значения   
   if ((!order.Valid()) || (atr1_period<1) || (atr2_period<1) || (coeff<=0) || (!order.Select()) || 
   ((atr_timeframe!=1) && (atr_timeframe!=5) && (atr_timeframe!=15) && (atr_timeframe!=30) && (atr_timeframe!=60) && 
   (atr_timeframe!=240) && (atr_timeframe!=1440) && (atr_timeframe!=10080) && (atr_timeframe!=43200)) || (atr1_shift<0) || (atr2_shift<0))
      {
      Print("Трейлинг функцией TrailingByATR() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      }
   
   double curr_atr1; // текущее значение ATR - 1
   double curr_atr2; // текущее значение ATR - 2
   double best_atr; // большее из значений ATR
   double atrXcoeff; // результат умножения большего из ATR на коэффициент
   double newstop; // новый стоплосс
   
   // текущее значение ATR-1, ATR-2
   curr_atr1 = Utils.iATR((ENUM_TIMEFRAMES)atr_timeframe,atr1_period,atr1_shift);
   curr_atr2 = Utils.iATR((ENUM_TIMEFRAMES)atr_timeframe,atr2_period,atr2_shift);
   
   // большее из значений
   best_atr = MathMax(curr_atr1,curr_atr2);
   
   // после умножения на коэффициент
   atrXcoeff = best_atr * coeff;
              
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
      double bid = Utils.Bid();
      // откладываем от текущего курса (новый стоплосс)
      newstop = bid - atrXcoeff;           
      // если trlinloss==true (т.е. следует тралить в зоне лоссов), то
      if (trlinloss==true)      
         {
         // если стоплосс неопределен, то тралим в любом случае
         if ((Utils.OrderStopLoss()==0) && (newstop<bid-Utils.StopLevelPoints()))
            {
               ChangeOrder(order, newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         // иначе тралим только если новый стоп лучше старого
         else
            {
            if ((newstop>Utils.OrderStopLoss()) && (newstop<bid-Utils.StopLevelPoints()))
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      else
         {
         // если стоплосс неопределен, то тралим, если стоп лучше открытия
         if ((Utils.OrderStopLoss()==0) && (newstop>Utils.OrderOpenPrice()) && (newstop<bid-Utils.StopLevelPoints()))
            {
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         // если стоп не равен 0, то меняем его, если он лучше предыдущего и курса открытия
         else
            {
            if ((newstop>Utils.OrderStopLoss()) && (newstop>Utils.OrderOpenPrice()) && (newstop<bid-Utils.StopLevelPoints()))
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
               //if (!OrderModify(ticket,Utils.OrderOpenPrice(),newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration()))
               //Print("Не удалось модифицировать ордер №",OrderTicket(),". Ошибка: ",GetLastError());
            }
         }
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      {
      double ask = Utils.Ask();
      // откладываем от текущего курса (новый стоплосс)
      newstop = ask + atrXcoeff;
      
      // если trlinloss==true (т.е. следует тралить в зоне лоссов), то
      if (trlinloss==true)      
         {
         // если стоплосс неопределен, то тралим в любом случае
         if ((Utils.OrderStopLoss()==0) && (newstop>ask+Utils.StopLevelPoints()))
            {
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         // иначе тралим только если новый стоп лучше старого
         else
            {
            if ((newstop<Utils.OrderStopLoss()) && (newstop>ask+Utils.StopLevelPoints()))
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      else
         {
         // если стоплосс неопределен, то тралим, если стоп лучше открытия
         if ((Utils.OrderStopLoss()==0) && (newstop<Utils.OrderOpenPrice()) && (newstop>ask+Utils.StopLevelPoints()))
            {
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         // если стоп не равен 0, то меняем его, если он лучше предыдущего и курса открытия
         else
            {
            if ((newstop<Utils.OrderStopLoss()) && (newstop<Utils.OrderOpenPrice()) && (newstop>ask+Utils.StopLevelPoints()))
               ChangeOrder(order,newstop,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         }
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ RATCHET БАРИШПОЛЬЦА                                     |
//| При достижении профитом уровня 1 стоплосс - в +1, при достижении |
//| профитом уровня 2 профита - стоплосс - на уровень 1, когда       |
//| профит достигает уровня 3 профита, стоплосс - на уровень 2       |
//| (дальше можно трейлить другими методами)                         |
//| при работе в лоссовом участке - тоже 3 уровня, но схема работы   |
//| с ними несколько иная, а именно: если мы опустились ниже уровня, |
//| а потом поднялись выше него (пример для покупки), то стоплосс    |
//| ставим на следующий, более глубокий уровень (например, уровни    |
//| -5, -10 и -25, стоплосс -40; если опустились ниже -10, а потом   |
//| поднялись выше -10, то стоплосс - на -25, если поднимемся выще   |
//| -5, то стоплосс перенесем на -10, при -2 (спрэд) стоп на -5      |
//| работаем только с одной позицией одновременно                    |
//+------------------------------------------------------------------+
void TrailingRatchetB(Order& order,int pf_level_1,int pf_level_2,int pf_level_3,int ls_level_1,int ls_level_2,int ls_level_3,bool trlinloss)
   {
    
   // проверяем переданные значения
   if ((!order.Valid()) || (!order.Select()) || (pf_level_2<=pf_level_1) || (pf_level_3<=pf_level_2) || 
   (pf_level_3<=pf_level_1) || (pf_level_2-pf_level_1<=Utils.StopLevelPoints()) || (pf_level_3-pf_level_2<=Utils.StopLevelPoints()) ||
   (pf_level_1<=Utils.StopLevel()))
      {
      Print("Трейлинг функцией TrailingRatchetB() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      }
                
   // если длинная позиция (OP_BUY)
   if (Utils.OrderType()==OP_BUY)
      {
      double dBid = Utils.Bid();
      
      // Работаем на участке профитов
      
      // если разница "текущий_курс-курс_открытия" больше чем "pf_level_3+спрэд", стоплосс переносим в "pf_level_2+спрэд"
      if ((dBid-Utils.OrderOpenPrice())>=pf_level_3*Point)
         {
         if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice() + pf_level_2 *Point))
            ChangeOrder(order,Utils.OrderOpenPrice() + pf_level_2*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      else
      // если разница "текущий_курс-курс_открытия" больше чем "pf_level_2+спрэд", стоплосс переносим в "pf_level_1+спрэд"
      if ((dBid-Utils.OrderOpenPrice())>=pf_level_2*Point)
         {
         if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice() + pf_level_1*Point))
            ChangeOrder(order,Utils.OrderOpenPrice() + pf_level_1*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      else        
      // если разница "текущий_курс-курс_открытия" больше чем "pf_level_1+спрэд", стоплосс переносим в +1 ("открытие + спрэд")
      if ((dBid-Utils.OrderOpenPrice())>=pf_level_1*Point)
      // если стоплосс не определен или хуже чем "открытие+1"
         {
         if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<Utils.OrderOpenPrice() + 1*Point))
            ChangeOrder(order,Utils.OrderOpenPrice() + 1*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }

      // Работаем на участке лоссов
      if (trlinloss==true)      
         {
         // Глобальная переменная терминала содержит значение самого уровня убытка (ls_level_n), ниже которого опускался курс
         // (если он после этого поднимается выше, устанавливаем стоплосс на ближайшем более глубоком уровне убытка (если это не начальный стоплосс позиции)
         // Создаём глобальную переменную (один раз)
         if(!GlobalVariableCheck("zeticket")) 
            {
            GlobalVariableSet("zeticket",order.ticket);
            // при создании присвоим ей "0"
            GlobalVariableSet("dpstlslvl",0);
            }
         // если работаем с новой сделкой (новый тикет), затираем значение dpstlslvl
         if (GlobalVariableGet("zeticket")!=order.ticket)
            {
            GlobalVariableSet("dpstlslvl",0);
            GlobalVariableSet("zeticket",order.ticket);
            }
      
         // убыточным считаем участок ниже курса открытия и до первого уровня профита
         if ((dBid-Utils.OrderOpenPrice())<pf_level_1*Point)         
            {
            // если (текущий_курс лучше/равно открытие) и (dpstlslvl>=ls_level_1), стоплосс - на ls_level_1
            if (dBid>=Utils.OrderOpenPrice()) 
            if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<(Utils.OrderOpenPrice()-ls_level_1*Point)))
              ChangeOrder(order,Utils.OrderOpenPrice()-ls_level_1*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
              //OrderModify(ticket,Utils.OrderOpenPrice(),Utils.OrderOpenPrice()-ls_level_1*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration());
      
            // если (текущий_курс лучше уровня_убытка_1) и (dpstlslvl>=ls_level_1), стоплосс - на ls_level_2
            if ((dBid>=Utils.OrderOpenPrice()-ls_level_1*Point) && (GlobalVariableGet("dpstlslvl")>=ls_level_1))
            if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<(Utils.OrderOpenPrice()-ls_level_2*Point)))
               ChangeOrder(order,Utils.OrderOpenPrice()-ls_level_2*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
               //OrderModify(ticket,Utils.OrderOpenPrice(),Utils.OrderOpenPrice()-ls_level_2*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration());
      
            // если (текущий_курс лучше уровня_убытка_2) и (dpstlslvl>=ls_level_2), стоплосс - на ls_level_3
            if ((dBid>=Utils.OrderOpenPrice()-ls_level_2*Point) && (GlobalVariableGet("dpstlslvl")>=ls_level_2))
            if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()<(Utils.OrderOpenPrice()-ls_level_3*Point)))
               ChangeOrder(order,Utils.OrderOpenPrice()-ls_level_3*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
               //OrderModify(ticket,Utils.OrderOpenPrice(),Utils.OrderOpenPrice()-ls_level_3*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration());
      
            // проверим/обновим значение наиболее глубокой "взятой" лоссовой "ступеньки"
            // если "текущий_курс-курс открытия+спрэд" меньше 0, 
            if ((dBid-Utils.OrderOpenPrice()+Utils.Spread()*Point)<0)
            // проверим, не меньше ли он того или иного уровня убытка
               {
               if (dBid<=Utils.OrderOpenPrice()-ls_level_3*Point)
               if (GlobalVariableGet("dpstlslvl")<ls_level_3)
               GlobalVariableSet("dpstlslvl",ls_level_3);
               else
               if (dBid<=Utils.OrderOpenPrice()-ls_level_2*Point)
               if (GlobalVariableGet("dpstlslvl")<ls_level_2)
               GlobalVariableSet("dpstlslvl",ls_level_2);   
               else
               if (dBid<=Utils.OrderOpenPrice()-ls_level_1*Point)
               if (GlobalVariableGet("dpstlslvl")<ls_level_1)
               GlobalVariableSet("dpstlslvl",ls_level_1);
               }
            } // end of "if ((dBid-Utils.OrderOpenPrice())<pf_level_1*Point)"
         } // end of "if (trlinloss==true)"
      }
      
   // если короткая позиция (OP_SELL)
   if (Utils.OrderType()==OP_SELL)
      {
      double dAsk = Utils.Ask();
      
      // Работаем на участке профитов
      
      // если разница "текущий_курс-курс_открытия" больше чем "pf_level_3+спрэд", стоплосс переносим в "pf_level_2+спрэд"
      if ((Utils.OrderOpenPrice()-dAsk)>=pf_level_3*Point)
         {
         if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice() - (pf_level_2 + Utils.Spread())*Point))
            ChangeOrder(order,Utils.OrderOpenPrice() - (pf_level_2 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            //OrderModify(ticket,Utils.OrderOpenPrice(),Utils.OrderOpenPrice() - (pf_level_2 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration());
         }
      else
      // если разница "текущий_курс-курс_открытия" больше чем "pf_level_2+спрэд", стоплосс переносим в "pf_level_1+спрэд"
      if ((Utils.OrderOpenPrice()-dAsk)>=pf_level_2*Point)
         {
         if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice() - (pf_level_1 + Utils.Spread())*Point))
            ChangeOrder(order,Utils.OrderOpenPrice() - (pf_level_1 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            //OrderModify(ticket,Utils.OrderOpenPrice(),Utils.OrderOpenPrice() - (pf_level_1 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration());
         }
      else        
      // если разница "текущий_курс-курс_открытия" больше чем "pf_level_1+спрэд", стоплосс переносим в +1 ("открытие + спрэд")
      if ((Utils.OrderOpenPrice()-dAsk)>=pf_level_1*Point)
      // если стоплосс не определен или хуже чем "открытие+1"
         {
         if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>Utils.OrderOpenPrice() - (1 + Utils.Spread())*Point))
            ChangeOrder(order,Utils.OrderOpenPrice() - (1 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            //OrderModify(ticket,Utils.OrderOpenPrice(),Utils.OrderOpenPrice() - (1 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration());
         }

      // Работаем на участке лоссов
      if (trlinloss==true)      
         {
         // Глобальная переменная терминала содержит значение самого уровня убытка (ls_level_n), ниже которого опускался курс
         // (если он после этого поднимается выше, устанавливаем стоплосс на ближайшем более глубоком уровне убытка (если это не начальный стоплосс позиции)
         // Создаём глобальную переменную (один раз)
         if(!GlobalVariableCheck("zeticket")) 
            {
            GlobalVariableSet("zeticket",order.ticket);
            // при создании присвоим ей "0"
            GlobalVariableSet("dpstlslvl",0);
            }
         // если работаем с новой сделкой (новый тикет), затираем значение dpstlslvl
         if (GlobalVariableGet("zeticket")!=order.ticket)
            {
            GlobalVariableSet("dpstlslvl",0);
            GlobalVariableSet("zeticket",order.ticket);
            }
      
         // убыточным считаем участок ниже курса открытия и до первого уровня профита
         if ((Utils.OrderOpenPrice()-dAsk)<pf_level_1*Point)         
            {
            // если (текущий_курс лучше/равно открытие) и (dpstlslvl>=ls_level_1), стоплосс - на ls_level_1
            if (dAsk<=Utils.OrderOpenPrice()) 
            if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>(Utils.OrderOpenPrice() + (ls_level_1 + Utils.Spread())*Point)))
                ChangeOrder(order,Utils.OrderOpenPrice() + (ls_level_1 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
      
            // если (текущий_курс лучше уровня_убытка_1) и (dpstlslvl>=ls_level_1), стоплосс - на ls_level_2
            if ((dAsk<=Utils.OrderOpenPrice() + (ls_level_1 + Utils.Spread())*Point) && (GlobalVariableGet("dpstlslvl")>=ls_level_1))
            if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>(Utils.OrderOpenPrice() + (ls_level_2 + Utils.Spread())*Point)))
               ChangeOrder(order,Utils.OrderOpenPrice() + (ls_level_2 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
      
            // если (текущий_курс лучше уровня_убытка_2) и (dpstlslvl>=ls_level_2), стоплосс - на ls_level_3
            if ((dAsk<=Utils.OrderOpenPrice() + (ls_level_2 + Utils.Spread())*Point) && (GlobalVariableGet("dpstlslvl")>=ls_level_2))
            if ((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>(Utils.OrderOpenPrice() + (ls_level_3 + Utils.Spread())*Point)))
               ChangeOrder(order,Utils.OrderOpenPrice() + (ls_level_3 + Utils.Spread())*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
      
            // проверим/обновим значение наиболее глубокой "взятой" лоссовой "ступеньки"
            // если "текущий_курс-курс открытия+спрэд" меньше 0, 
            if ((Utils.OrderOpenPrice()-dAsk+Utils.Spread()*Point)<0)
            // проверим, не меньше ли он того или иного уровня убытка
               {
               if (dAsk>=Utils.OrderOpenPrice()+(ls_level_3+Utils.Spread())*Point)
               if (GlobalVariableGet("dpstlslvl")<ls_level_3)
               GlobalVariableSet("dpstlslvl",ls_level_3);
               else
               if (dAsk>=Utils.OrderOpenPrice()+(ls_level_2+Utils.Spread())*Point)
               if (GlobalVariableGet("dpstlslvl")<ls_level_2)
               GlobalVariableSet("dpstlslvl",ls_level_2);   
               else
               if (dAsk>=Utils.OrderOpenPrice()+(ls_level_1+Utils.Spread())*Point)
               if (GlobalVariableGet("dpstlslvl")<ls_level_1)
               GlobalVariableSet("dpstlslvl",ls_level_1);
               }
            } // end of "if ((dBid-Utils.OrderOpenPrice())<pf_level_1*Point)"
         } // end of "if (trlinloss==true)"
      }      
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО ЦЕНВОМУ КАНАЛУ                                       |
//| Функции передаётся тикет позиции, период (кол-во баров) для      | 
//| рассчета верхней и нижней границ канала, отступ (пунктов), на    |
//| котором размещается стоплосс от границы канала                   |
//| Трейлинг по закрывшимся барам.                                   |
//+------------------------------------------------------------------+
void TrailingByPriceChannel(Order& order,int iBars_n,int iIndent)
   {     
   
   // проверяем переданные значения
   if ((iBars_n<1) || (iIndent<0) || (!order.Valid()) || (!order.Select()))
      {
      Print("Трейлинг функцией TrailingByPriceChannel() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 
   
   double   dChnl_max; // верхняя граница канала
   double   dChnl_min; // нижняя граница канала
   
   // определяем макс.хай и мин.лоу за iBars_n баров начиная с [1] (= верхняя и нижняя границы ценового канала)
   dChnl_max = iHigh(Symbol, Period(), iHighest(Symbol(),0,2,iBars_n,1)) + (iIndent+Utils.Spread())*Point;
   dChnl_min = iLow(Symbol, Period(), iLowest(Symbol(),0,1,iBars_n,1)) - iIndent*Point;   
   
   // если длинная позиция, и её стоплосс хуже (ниже нижней границы канала либо не определен, ==0), модифицируем его
   if (order.type == OP_BUY)
      {
      if ((Utils.OrderStopLoss()<dChnl_min) && (dChnl_min<Utils.Bid()-Utils.StopLevelPoints()))
         {
            //if (MaxStopLoss != 0)
            //   dChnl_min = MathMax(Bid - MaxStopLoss * Point, dChnl_min);
            //double TP = OrderTakeProfit();
            //if (MaxTakeProfit != 0)
            //   TP = Ask + MaxTakeProfit* Point;
            ChangeOrder(order,dChnl_min,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
   
   // если позиция - короткая, и её стоплосс хуже (выше верхней границы канала или не определён, ==0), модифицируем его
   if (order.type == OP_SELL)
      {
      if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>dChnl_max)) && (dChnl_min>Utils.Ask()+Utils.StopLevelPoints()))
         {
            //if (MaxStopLoss != 0)
            //   dChnl_max = MathMin(Ask + MaxStopLoss * Point, dChnl_max);
            //double TP = OrderTakeProfit();
            //if (MaxTakeProfit != 0)
            //  TP = Bid - MaxTakeProfit* Point;
            ChangeOrder(order,dChnl_max,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ ПО СКОЛЬЗЯЩЕМУ СРЕДНЕМУ                                 |
//| Функции передаётся тикет позиции и параметры средней (таймфрейм, | 
//| период, тип, сдвиг относительно графика, метод сглаживания,      |
//| составляющая OHCL для построения, № бара, на котором берется     |
//| значение средней.                                                |
//+------------------------------------------------------------------+

//    Допустимые варианты ввода:   
//    iTmFrme:    1 (M1), 5 (M5), 15 (M15), 30 (M30), 60 (H1), 240 (H4), 1440 (D), 10080 (W), 43200 (MN);
//    iMAPeriod:  2-infinity, целые числа; 
//    iMAShift:   целые положительные или отрицательные числа, а также 0;
//    MAMethod:   0 (MODE_SMA), 1 (MODE_EMA), 2 (MODE_SMMA), 3 (MODE_LWMA);
//    iApplPrice: 0 (PRICE_CLOSE), 1 (PRICE_OPEN), 2 (PRICE_HIGH), 3 (PRICE_LOW), 4 (PRICE_MEDIAN), 5 (PRICE_TYPICAL), 6 (PRICE_WEIGHTED)
//    iShift:     0-Bars, целые числа;
//    iIndent:    0-infinity, целые числа;

void TrailingByMA(Order& order,int iTmFrme,int iMAPeriod,int iMAShift,int MAMethod,int iApplPrice,int iShift,int iIndent)
   {     
   
   // проверяем переданные значения
   if ((!order.Valid()) || (!order.Select()) || ((iTmFrme!=1) && (iTmFrme!=5) && (iTmFrme!=15) && (iTmFrme!=30) && (iTmFrme!=60) && (iTmFrme!=240) && (iTmFrme!=1440) && (iTmFrme!=10080) && (iTmFrme!=43200)) ||
   (iMAPeriod<2) || (MAMethod<0) || (MAMethod>3) || (iApplPrice<0) || (iApplPrice>6) || (iShift<0) || (iIndent<0))
      {
      Print("Трейлинг функцией TrailingByMA() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      } 

   double   dMA; // значение скользящего среднего с переданными параметрами
   
   // определим значение МА с переданными функции параметрами
   dMA = Utils.iMA((ENUM_TIMEFRAMES)iTmFrme,iMAPeriod,iMAShift,(ENUM_MA_METHOD)MAMethod,(ENUM_APPLIED_PRICE)iApplPrice,iShift);
         
   // если длинная позиция, и её стоплосс хуже значения среднего с отступом в iIndent пунктов, модифицируем его
   if (Utils.OrderType()==OP_BUY)
      {
      if ((Utils.OrderStopLoss()<dMA-iIndent*Point) && (dMA-iIndent*Point<Utils.Bid()-Utils.StopLevelPoints()))
         {
            ChangeOrder(order,dMA-iIndent*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
   
   // если позиция - короткая, и её стоплосс хуже (выше верхней границы канала или не определён, ==0), модифицируем его
   if (Utils.OrderType()==OP_SELL)
      {
      if (((Utils.OrderStopLoss()==0) || (Utils.OrderStopLoss()>dMA+(Utils.Spread()+iIndent)*Point)) && (dMA+(Utils.Spread()+iIndent)*Point>Utils.Ask()+Utils.StopLevelPoints()))
         {
            ChangeOrder(order,dMA+(Utils.Spread()+iIndent)*Point,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
         }
      }
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ "ПОЛОВИНЯЩИЙ"                                           |
//| По закрытии очередного периода (бара) подтягиваем стоплосс на    |
//| половину (но можно и любой иной коэффициент) дистанции, прой-    |
//| денной курсом (т.е., например, по закрытии суток профит +55 п. - |
//| стоплосс переносим в 55/2=27 п. Если по закрытии след.           |
//| суток профит достиг, допустим, +80 п., то стоплосс переносим на  |
//| половину (напр.) расстояния между тек. стоплоссом и курсом на    |
//| закрытии бара - 27 + (80-27)/2 = 27 + 53/2 = 27 + 26 = 53 п.     |
//| iTicket - тикет позиции; iTmFrme - таймфрейм (в минутах, цифрами |
//| dCoeff - "коэффициент поджатия", в % от 0.01 до 1 (в последнем   |
//| случае стоплосс будет перенесен (если получится) вплотную к тек. |
//| курсу и позиция, скорее всего, сразу же закроется)               |
//| bTrlinloss - стоит ли тралить на лоссовом участке - если да, то  |
//| по закрытию очередного бара расстояние между стоплоссом (в т.ч.  |
//| "до" безубытка) и текущим курсом будет сокращаться в dCoeff раз  |
//| чтобы посл. вариант работал, обязательно должен быть определён   |
//| стоплосс (не равен 0)                                            |
//+------------------------------------------------------------------+

void TrailingFiftyFifty(Order& order,int iTmFrme,double dCoeff,bool bTrlinloss)
   { 
   // активируем трейлинг только по закрытии бара
   if (sdtPrevtime == iTime(Symbol(),iTmFrme,0)) 
      return;
   else
      {
      sdtPrevtime = iTime(Symbol(),iTmFrme,0);             
      
      // проверяем переданные значения
      if ((!order.Valid()) || (!order.Select()) || 
      ((iTmFrme!=1) && (iTmFrme!=5) && (iTmFrme!=15) && (iTmFrme!=30) && (iTmFrme!=60) && (iTmFrme!=240) && 
      (iTmFrme!=1440) && (iTmFrme!=10080) && (iTmFrme!=43200)) || (dCoeff<0.01) || (dCoeff>1.0))
         {
         Print("Трейлинг функцией TrailingFiftyFifty() невозможен из-за некорректности значений переданных ей аргументов.");
         return;
         }
         
      // начинаем тралить - с первого бара после открывающего (иначе при bTrlinloss сразу же после открытия 
      // позиции стоплосс будет перенесен на половину расстояния между стоплоссом и курсом открытия)
      // т.е. работаем только при условии, что с момента OrderOpenTime() прошло не менее iTmFrme минут
      if (iTime(Symbol(),iTmFrme,0)>Utils.OrderOpenTime())
      {         
      
      double dBid = Utils.Bid();
      double dAsk = Utils.Ask();
      double dNewSl = 0;
      double dNexMove = 0;     
      
      // для длинной позиции переносим стоплосс на dCoeff дистанции от курса открытия до Bid на момент открытия бара
      // (если такой стоплосс лучше имеющегося и изменяет стоплосс в сторону профита)
      if (Utils.OrderType()==OP_BUY)
         {
         if ((bTrlinloss) && (Utils.OrderStopLoss()!=0))
            {
            dNexMove = NormalizeDouble(dCoeff*(dBid-Utils.OrderStopLoss()),Digits);
            dNewSl = NormalizeDouble(Utils.OrderStopLoss()+dNexMove,Digits);            
            }
         else
            {
            // если стоплосс ниже курса открытия, то тралим "от курса открытия"
            if (Utils.OrderOpenPrice()>Utils.OrderStopLoss())
               {
               dNexMove = NormalizeDouble(dCoeff*(dBid-Utils.OrderOpenPrice()),Digits);                 
               //Print("dNexMove = ",dCoeff,"*(",dBid,"-",Utils.OrderOpenPrice(),")");
               dNewSl = NormalizeDouble(Utils.OrderOpenPrice()+dNexMove,Digits);
               //Print("dNewSl = ",Utils.OrderOpenPrice(),"+",dNexMove);
               }
         
            // если стоплосс выше курса открытия, тралим от стоплосса
            if (Utils.OrderStopLoss()>=Utils.OrderOpenPrice())
               {
               dNexMove = NormalizeDouble(dCoeff*(dBid-Utils.OrderStopLoss()),Digits);
               dNewSl = NormalizeDouble(Utils.OrderStopLoss()+dNexMove,Digits);
               }                                      
            }
            
         // стоплосс перемещаем только в случае, если новый стоплосс лучше текущего и если смещение - в сторону профита
         // (при первом поджатии, от курса открытия, новый стоплосс может быть лучше имеющегося, и в то же время ниже 
         // курса открытия (если dBid ниже последнего) 
         if ((dNewSl>Utils.OrderStopLoss()) && (dNexMove>0) && ((dNewSl<dBid- Utils.StopLevelPoints())))
            {
               ChangeOrder(order,dNewSl,Utils.OrderTakeProfit(),Utils.OrderExpiration(),Red);
            }
         }       
      
      // действия для короткой позиции   
      if (Utils.OrderType()==OP_SELL)
         {
         if ((bTrlinloss) && (Utils.OrderStopLoss()!=0))
            {
            dNexMove = NormalizeDouble(dCoeff*(Utils.OrderStopLoss()-(dAsk+Utils.Spread()*Point)),Digits);
            dNewSl = NormalizeDouble(Utils.OrderStopLoss()-dNexMove,Digits);            
            }
         else
            {         
            // если стоплосс выше курса открытия, то тралим "от курса открытия"
            if (Utils.OrderOpenPrice()<Utils.OrderStopLoss())
               {
               dNexMove = NormalizeDouble(dCoeff*(Utils.OrderOpenPrice()-(dAsk+Utils.Spread()*Point)),Digits);                 
               dNewSl = NormalizeDouble(Utils.OrderOpenPrice()-dNexMove,Digits);
               }
         
            // если стоплосс нижу курса открытия, тралим от стоплосса
            if (Utils.OrderStopLoss()<=Utils.OrderOpenPrice())
               {
               dNexMove = NormalizeDouble(dCoeff*(Utils.OrderStopLoss()-(dAsk+Utils.Spread()*Point)),Digits);
               dNewSl = NormalizeDouble(Utils.OrderStopLoss()-dNexMove,Digits);
               }                  
            }
         
         // стоплосс перемещаем только в случае, если новый стоплосс лучше текущего и если смещение - в сторону профита
         if ((dNewSl<Utils.OrderStopLoss()) && (dNexMove>0) && (dNewSl>dAsk+Utils.StopLevelPoints()))
            {
               ChangeOrder(order,dNewSl,Utils.OrderTakeProfit(),Utils.OrderExpiration(),Blue);
            }
         }               
      }
      }   
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ТРЕЙЛИНГ KillLoss                                                |
//| Применяется на участке лоссов. Суть: стоплосс движется навстречу |
//| курсу со скоростью движения курса х коэффициент (dSpeedCoeff).   |
//| При этом коэффициент можно "привязать" к скорости увеличения     |
//| убытка - так, чтобы при быстром росте лосса потерять меньше. При |
//| коэффициенте = 1 стоплосс сработает ровно посредине между уров-  |
//| нем стоплосса и курсом на момент запуска функции, при коэфф.>1   |
//| точка встречи курса и стоплосса будет смещена в сторону исход-   |
//| ного положения курса, при коэфф.<1 - наоборот, ближе к исходно-  |
//| му стоплоссу.                                                    |
//+------------------------------------------------------------------+

void KillLoss(Order& order,double dSpeedCoeff)
   {   
   // проверяем переданные значения
   if ((!order.Valid()) || (!order.Valid()) || (dSpeedCoeff<0.1))
      {
      Print("Трейлинг функцией KillLoss() невозможен из-за некорректности значений переданных ей аргументов.");
      return;
      }           
      
   double dStopPriceDiff = 0; // расстояние (пунктов) между курсом и стоплоссом   
   double dToMove; // кол-во пунктов, на которое следует переместить стоплосс   
   // текущий курс
   double dBid = Utils.Bid();
   double dAsk = Utils.Ask();      
   
   // текущее расстояние между курсом и стоплоссом
   if (Utils.OrderType()==OP_BUY) dStopPriceDiff = dBid -Utils.OrderStopLoss();
   if (Utils.OrderType()==OP_SELL) dStopPriceDiff = (Utils.OrderStopLoss() + Utils.Spread()*Point) - dAsk;                  
   
   // проверяем, если тикет != тикету, с которым работали раньше, запоминаем текущее расстояние между курсом и стоплоссом
   if (GlobalVariableGet("zeticket")!=order.ticket)
      {
      GlobalVariableSet("sldiff",dStopPriceDiff);      
      GlobalVariableSet("zeticket",order.ticket);
      }
   else
      {                                   
      // итак, у нас есть коэффициент ускорения изменения курса
      // на каждый пункт, который проходит курс в сторону лосса, 
      // мы должны переместить стоплосс ему на встречу на dSpeedCoeff раз пунктов
      // (например, если лосс увеличился на 3 пункта за тик, dSpeedCoeff = 1.5, то
      // стоплосс подтягиваем на 3 х 1.5 = 4.5, округляем - 5 п. Если подтянуть не 
      // удаётся (слишком близко), ничего не делаем.            
      
      // кол-во пунктов, на которое приблизился курс к стоплоссу с момента предыдущей проверки (тика, по идее)
      dToMove = (GlobalVariableGet("sldiff") - dStopPriceDiff) / Point;
      
      // записываем новое значение, но только если оно уменьшилось
      if (dStopPriceDiff<GlobalVariableGet("sldiff"))
      GlobalVariableSet("sldiff",dStopPriceDiff);
      
      // дальше действия на случай, если расстояние уменьшилось (т.е. курс приблизился к стоплоссу, убыток растет)
      if (dToMove>0)
         {       
         // стоплосс, соответственно, нужно также передвинуть на такое же расстояние, но с учетом коэфф. ускорения
         dToMove = MathRound(dToMove * dSpeedCoeff) * Point;                 
      
         // теперь проверим, можем ли мы подтянуть стоплосс на такое расстояние
         if (Utils.OrderType()==OP_BUY)
            {
            if (dBid - (Utils.OrderStopLoss() + dToMove)>Utils.StopLevelPoints())
               ChangeOrder(order,Utils.OrderStopLoss() + dToMove,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }
         if (Utils.OrderType()==OP_SELL)
            {
            if ((Utils.OrderStopLoss() - dToMove) - dAsk>Utils.StopLevelPoints())
               ChangeOrder(order,Utils.OrderStopLoss() - dToMove,Utils.OrderTakeProfit(),Utils.OrderExpiration(), TrailingColor);
            }      
         }
      }            
   }
   
   //+------------------------------------------------------------------+ 

};


//+------------------------------------------------------------------+
//|                                                 ThriftClient.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <XTrade\IUtils.mqh>
#include <XTrade\ITradeService.mqh>

class TradeExpert;

#include <XTrade\GenericTypes.mqh>
#include <XTrade\TradeExpert.mqh>
#include <XTrade\Signals.mqh>
#include <XTrade\Deal.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CommandsController 
{
protected:
   ITradeService *thrift;
   TradeExpert   *expert;
public:
   
   CommandsController(TradeExpert* ex)
   {
       expert = ex;
       thrift = Utils.Service();
   }
   
   bool CheckActive();
   
   void HandleSignal(int id, long lparam, double dparam, string signalStr);
   void ReturnActiveOrders();
   void DealsHistory(int days);

   ~CommandsController()
   {
   
   }
};

bool CommandsController::CheckActive() 
{   
   return thrift.CheckActive();
}
   
void CommandsController::HandleSignal(int id, long lparam, double dparam, string signalStr)
{
   //Utils.Info("Received event from server: " + IntegerToString(lparam) + ": " + DoubleToString(dparam));
   SignalType signalId = (SignalType)(id - CHARTEVENT_CUSTOM);
   switch (signalId) {
      case SIGNAL_CHECK_BALANCE: {
          Signal* retSignal = new Signal(SignalToServer, SIGNAL_CHECK_BALANCE, thrift.MagicNumber());
          CJAVal obj;
          obj["Balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
          obj["Equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
          obj["Account"] = (long)Utils.AccountNumber();
          retSignal.obj["Data"].Add(obj);
          thrift.PostSignal(retSignal);
          
      } break;
      case SIGNAL_INIT_EXPERT:
         
      break;
      case SIGNAL_UPDATE_SLTP:
         Utils.Trade().UpdateStopLossesTakeProfits(true);
      break;
      case SIGNAL_UPDATE_EXPERT:
         expert.ReloadExpert();
      break;
      case SIGNAL_MARKET_MANUAL_ORDER:
      {
         Signal signal(signalStr);
         if (thrift.IsMaster() && (signal.flags == SignalToCluster))
         {
            Signal* clusterSignal = new Signal(SignalToCluster, signalId, thrift.MagicNumber());
            clusterSignal.Value = signal.Value;
            thrift.PostSignal(clusterSignal);
         } else {
            Order* order =  expert.methods.InitManualOrder(signal.Value);
            order.comment = signal.GetName();
            expert.methods.OpenOrder(order);
         }
      } break;
      case SIGNAL_MARKET_EXPERT_ORDER: 
      {
         Signal signal(signalStr);
         if (thrift.IsMaster())
         {
            Signal* clusterSignal = new Signal(SignalToCluster, signalId, thrift.MagicNumber());
            clusterSignal.Value = signal.Value;
            thrift.PostSignal(clusterSignal);
         } else {
            Order* order = expert.methods.InitExpertOrder(signal.Value);
            order.comment = signal.GetName();
            expert.methods.OpenOrder(order);
         }
      } break;
      case SIGNAL_MARKET_FROMPENDING_ORDER: {
         //Signal signal(signalStr);
         //if ( signal.Value == 0 ) 
         //   expert.OpenOrder(expert.InitFromPending(OP_BUY));
         //else 
         //   expert.OpenOrder(expert.InitFromPending(OP_SELL));
      } break;
      case SIGNAL_ACTIVE_ORDERS:
         ReturnActiveOrders();     
      break;
      case SIGNAL_CLOSE_POSITION:
      {
         Signal signal(signalStr);
         OrderSelection* orders = Utils.Trade().Orders();
         Order* order = orders.SearchOrder(signal.Value);
         if (order != NULL) 
         {
            Utils.Info(StringFormat("**Manual Close Order**: %s p=%g", order.ToString(), order.RealProfit()));
            if (order.isPending())
            {
               expert.methods.DeletePendingOrder(order);
            } else 
            {
               order.MarkToClose();
            }
         }
      } break;
      case SIGNAL_DEALS_HISTORY: {
         DealsHistory((int)dparam);
      } break;
   }
}

void CommandsController::ReturnActiveOrders() 
{
   Signal* retSignal = new Signal(SignalToServer, SIGNAL_ACTIVE_ORDERS, thrift.MagicNumber());
   retSignal.Value = (int)Utils.GetAccountNumer();
   OrderSelection* orders = Utils.Trade().Orders();
   FOREACH_ORDER(orders)
   {
       if (order.isPending())
          retSignal.obj["Data"].Add(order.Persistent());
   }   
   for (int i = Utils.OrdersTotal() - 1; i >= 0; i-- )
   {     
      if (Utils.SelectOrderByPos(i))
      {
         long Ticket = Utils.OrderTicket();
         Order* oldOrder = orders.SearchOrder(Ticket);
         if (oldOrder != NULL)
         {
            orders.Fill(oldOrder);
            retSignal.obj["Data"].Add(oldOrder.Persistent());
         } else 
         {
            //long Magic = Utils.OrderMagicNumber();
            //if ( Magic <= 0 ) // for external orders only
            //{
               Order* newOrder = new Order(Ticket);
               orders.Fill(newOrder);
               retSignal.obj["Data"].Add(newOrder.Persistent());
               DELETE_PTR(newOrder);
            //}
         }
       }
   }
   thrift.PostSignal(retSignal);
}

void CommandsController::DealsHistory(int days) 
{
    datetime dto = TimeCurrent();
    MqlDateTime mqlDt;
    TimeToStruct(dto, mqlDt);
    mqlDt.day_of_year = mqlDt.day_of_year - days;
    mqlDt.day = mqlDt.day - days;
    datetime from = StructToTime(mqlDt);
    if (days <= 0)
      from = 0;
    if (!HistorySelect(from, dto))
    {
         Utils.Info(StringFormat("Failed to retrieve Deals history for %d days", days));
         return;
    }
    uint total = HistoryDealsTotal(); 
    if ( total <= 0 )
       return;
    ulong ticket = 0;
    Signal* retSignal = new Signal(SignalToServer, SIGNAL_DEALS_HISTORY, thrift.MagicNumber());
    for ( uint i=0;i<total;i++ )
    { 
         if ((ticket = HistoryDealGetTicket(i)) > 0) 
         {
            Deal* deal = new Deal(ticket);
            if (deal.entry == DEAL_ENTRY_IN) 
               continue;
            retSignal.obj["Data"].Add(deal.Persistent());
         }
    }
    thrift.PostSignal(retSignal);
}

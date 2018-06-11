//+------------------------------------------------------------------+
//|                                                 ThriftClient.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict

#include <FXMind\SettingsFile.mqh>
#include <FXMind\IUtils.mqh>
#include <FXMind\InputTypes.mqh>

struct THRIFT_CLIENT
{
   int port;
   int Magic;
   int accountNumber;
   int Reserved;
   //uchar ip0;
   //uchar ip1;
   //uchar ip2;
   //uchar ip3;
};



//../../../Common/Libraries/
#import "ThriftMQL.dll"
long ProcessStringData(string& inoutdata, string parameters, THRIFT_CLIENT &tc);
long ProcessDoubleData(double &arr[], int arr_size, string parameters, string indata, THRIFT_CLIENT &tc);
long IsServerActive(THRIFT_CLIENT &tc);
void PostStatusMessage(THRIFT_CLIENT &tc, string message);
void GetGlobalProperty(string& RetValue, string PropName, THRIFT_CLIENT &tc); // returns length of the result value. -1 - on error
long InitExpert(string& OrdersListToLoad, string ChartTimeFrame, string Symbol, string comment, THRIFT_CLIENT &tc); // Returns Magic Number, 0 or error
void SaveExpert(string ActiveOrdersList, THRIFT_CLIENT &tc);
void DeInitExpert(int Reason, THRIFT_CLIENT &tc); // DeInit for Expert Advisers only
void CloseClient(THRIFT_CLIENT &tc); // Free memory
#import


class  NewsEventInfo
{
 public:
  string Currency;
  int     Importance;
  datetime RaiseDateTime; // date returned in MTFormat
  string Name;
  
  NewsEventInfo()
  {
      Name = "No news";
      Currency = "UnDefined";
      Importance = 0;
  }
    
  void Clear()
  {
     Name = "No news";
     Currency = "";
     Importance =0;
     RaiseDateTime = 0;
  }
  
   void operator=(const NewsEventInfo &n) {
      Currency = n.Currency;
      Importance = n.Importance;
      RaiseDateTime = n.RaiseDateTime;
      Name = n.Name;
   }
      
  bool operator==(const NewsEventInfo &n)
  {
     if (StringCompare(Name, n.Name)!=0)
        return false;
     if (RaiseDateTime != n.RaiseDateTime)
        return false;
     if (Importance != n.Importance)
        return false;
     if (StringCompare(Currency, n.Currency) !=0)
        return false;
     return true;
  }
  
   bool operator!=(const NewsEventInfo &n)
   {
     if (StringCompare(Name, n.Name)!=0)
        return true;
     if (RaiseDateTime != n.RaiseDateTime)
        return true;
     if (Importance != n.Importance)
        return true;
     if (StringCompare(Currency, n.Currency) !=0)
        return true;
     return false;
   }
  
  string DateToString()
  {
      MqlDateTime mqlDate;
      TimeToStruct(RaiseDateTime, mqlDate);
      return StringFormat("%02d/%02d %02d:%02d", mqlDate.mon, mqlDate.day, mqlDate.hour, mqlDate.min);
  }
  
  string ToString()
  {
     if (StringCompare("No news", Name)==0)
        return "";
     return Currency + " "+ IntegerToString(Importance) + " " + DateToString() + " " + Name;
  }
};

#define MAX_NEWS_PER_DAY  5


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class FXMindClient 
{
protected:
   THRIFT_CLIENT client;
   bool   IsActive;
public:
   Constants constant;
   ushort sep;   
   ushort sepList; 
   int MagicNumber;
   string fileName;
   SettingsFile* set;
   string EAName;
   string sym;

   FXMindClient(short Port, string EA)
   {
      sep = StringGetCharacter(constant.PARAMS_SEPARATOR, 0);
      sepList = StringGetCharacter(constant.LIST_SEPARATOR, 0);
      //client.ip0 = 127;
      //client.ip1 = 0;
      //client.ip2 = 0;
      //client.ip3 = 1;
      client.port = Port;
      client.accountNumber = (int)Utils.GetAccountNumer();
      EAName = EA;
      sym = "";
   }

   virtual bool Init() // Should be called after MagicNumber obtained
   {
      string periodStr = EnumToString((ENUM_TIMEFRAMES)Period());
      sym = Symbol();
      if (StringLen(sym) > 6)
         sym = StringSubstr(sym, 0, 6);
   	string rawOrdersList;
   	StringInit(rawOrdersList, BUFF_SIZE, 0);
      long Magic = InitExpert(rawOrdersList, periodStr, sym, EAName, client);
      if (Magic <= 0)
      {
         Print(StringFormat("InitExpert(%d, %s, %s) FAILED!!!", client.accountNumber, periodStr, sym));
         return false;
      }
      client.Magic = (int)Magic;
      MagicNumber = (int)Magic;
      
      fileName = StringFormat("%d_%s_%s_%d.set", client.accountNumber, sym, periodStr, MagicNumber);
      
      IsActive = false;
      CheckActive();
      
      set = new SettingsFile(constant.GLOBAL_SECTION_NAME, fileName);
      set.SetOrdersStringList(rawOrdersList, sep);

      storeEventTime = TimeCurrent();
      prevSenttime = storeEventTime;
      return IsActive;
   }

   bool CheckActive() {   
      IsActive = IsServerActive(client) > 0;
      return IsActive;
   }
   
   bool isActive() {   
      return IsActive;
   }
   
   bool NewsFromString(string newsstring, NewsEventInfo& news)
   {
      //Print(newsstring);
      string result[];
      if (StringGetCharacter(newsstring, 0) == sep)
         newsstring = StringSubstr(newsstring, 1);
      int count = StringSplit(newsstring, sep, result);
      if (count >= 4) 
      {
         news.Currency = result[0];
         news.Importance = (int)StringToInteger(result[1]);
         news.RaiseDateTime = StringToTime(result[2]);
         news.Name = result[3];
         //Print(news.ToString());
         return true;
      }
      return false;
   }
   
   datetime storeEventTime;
   NewsEventInfo storeEvent;
   string storeParamstrEvent;
   bool GetNextNewsEvent(ushort Importance, NewsEventInfo& eventInfo)
   {
      //datetime curtime = iTime( NULL, PERIOD_M15, 0 );
      datetime curtime = Utils.CurrentTimeOnTF();
      if (storeEventTime != curtime)
         storeEventTime = curtime;
      else
      { 
         eventInfo = storeEvent;
         return true;
      }
      string instr = StringFormat("func=NextNewsEvent|symbol=%s|importance=%d|time=%s", sym, Importance, TimeToString(curtime));
   	if ( StringCompare(storeParamstrEvent, instr) == 0)
      { 
         eventInfo = storeEvent;
         return true;
      }
   	storeParamstrEvent = instr;
   	string rawMessage;
   	StringInit(rawMessage, BUFF_SIZE, 0);
   	long retval = ProcessStringData(rawMessage, instr, client);
   	if ( retval > 0 )
   	{
   	   if (NewsFromString(rawMessage, eventInfo))
   	   {
   	      storeEvent = eventInfo;
   	      //Print(eventInfo.ToString());
   	      return true;
   	   }
   	}
   	return false;
   }
   
   string storeParamstr;
   int GetTodayNews(ushort Importance, NewsEventInfo &arr[])
   {
      datetime curtime = Utils.CurrentTimeOnTF();
   	string instr = "func=GetTodayNews|symbol=" + sym + "|importance=" + IntegerToString(Importance) + "|time=" + TimeToString(curtime);
   	if ( StringCompare(storeParamstr, instr) == 0)
         return 0;
   	storeParamstr = instr;
   	int storeRes = 0;
   	string rawMessage;
   	StringInit(rawMessage, MAX_NEWS_PER_DAY*BUFF_SIZE, 0);
   	long retval = ProcessStringData(rawMessage, instr, client);
   	if ( retval > 0 )
   	{
   	   //Print(rawMessage);
         string result[];
         int count = StringSplit(rawMessage, sepList, result);
         count = (int)MathMin(count, MAX_NEWS_PER_DAY);
         if (count >= 1) {
            for (int i=0; i<MAX_NEWS_PER_DAY;i++)
            { 
               arr[i].Clear();
            }
            storeRes = count;
            for (int i=0; i<count;i++)
            {                
               NewsFromString(result[i], arr[i]);
            }
         }
   	}
   	return storeRes;
   }
   
   string oldSentstr;
   datetime prevSenttime;
   int GetCurrentSentiments(double& longVal, double& shortVal) 
   {
      datetime curtime = Utils.CurrentTimeOnTF();
      if (prevSenttime != curtime)
         prevSenttime = curtime;
      else
         return 0;
   	string instr = "func=CurrentSentiments|symbol=" + sym + "|time=" + TimeToString(curtime);
   	if ( StringCompare(oldSentstr, instr) == 0)
   	   return 0;
   	oldSentstr = instr;
   	double resDouble[2];
   	//ArrayResize(resDouble, 2);
   	ArrayFill(resDouble, 0, 2, 0);
   	string rawMessage = "0|0";
   	long retval = ProcessDoubleData(resDouble, 2, instr, rawMessage, client);
   	int res = 0;   	
   	if ( retval == 0 )
   	{
         longVal = resDouble[0];
         shortVal = resDouble[1];
         res = 1;
      } else 
            res = 0;
      return res;
   }
   
   long GetSentimentsArray(int offset, int limit, int site, const datetime& times[], double &arr[])
   {
   	string parameters = "func=SentimentsArray|symbol=" + sym + "|size=" + IntegerToString(limit)
   	   + "|site=" + IntegerToString(site);
   	string timeArray;
   	for (int i = 0; i < limit; i++)
   	{
  	      timeArray += TimeToString(times[i]);
  	      if (i < (limit-1) )
  	         timeArray += "|";
     	}
     	double retarr[];
     	ArrayResize(retarr, limit);
      long retval = ProcessDoubleData(retarr, limit, parameters, timeArray, client);
      ArrayCopy(arr, retarr, offset, 0, limit);
      return retval;
   }

   long GetCurrencyStrengthArray(string currency, int offset, int limit, int timeframe, const datetime& times[], double &arr[])
   {
   	string parameters = "func=CurrencyStrengthArray|currency=" + currency + "|timeframe=" + IntegerToString(timeframe);
   	string timeArray;
   	for (int i = 0; i < limit; i++)
   	{
  	      timeArray += TimeToString(times[i]);
  	      if (i < (limit-1) )
  	         timeArray += "|";
     	}
     	double retarr[];
     	ArrayResize(retarr, limit);
      long retval = ProcessDoubleData(retarr, limit, parameters, timeArray, client);
      ArrayCopy(arr, retarr, offset, 0, limit);
      return retval;
   }
   
   void PostMessage(string message) 
   {
      PostStatusMessage(client, message);
   }
   
   
   void SaveAllSettings(string ActiveOrdersList)
   {
      
      SaveExpert(ActiveOrdersList, client);
   }
   
   string ReasonToString(int Reason)
   {
      switch ( Reason) 
      {
         case REASON_PROGRAM: //0
            return "0 REASON_PROGRAM - Эксперт прекратил свою работу, вызвав функцию ExpertRemove()";
         case REASON_REMOVE: //1
            return "1 REASON_REMOVE Программа удалена с графика";
         case REASON_RECOMPILE: // 2
            return "2 REASON_RECOMPILE Программа перекомпилирована";
         case REASON_CHARTCHANGE: //3
            return "3 REASON_CHARTCHANGE Символ или период графика был изменен";
         case REASON_CHARTCLOSE:
            return "4 REASON_CHARTCLOSE График закрыт";
         case REASON_PARAMETERS:          
            return "5 REASON_PARAMETERS Входные параметры были изменены пользователем";       
         case REASON_ACCOUNT:
            return "6 Активирован другой счет либо произошло переподключение к торговому серверу вследствие изменения настроек счета";
         case REASON_TEMPLATE:           
            return "7 REASON_TEMPLATE Применен другой шаблон графика";
         case REASON_INITFAILED:
            return "8 REASON_INITFAILED Признак того, что обработчик OnInit() вернул ненулевое значение";
         case REASON_CLOSE:
            return "9 REASON_CLOSE Терминал был закрыт";
      }  
      return StringFormat("Unknown reason: %s", Reason);
   }

   virtual uint DeInit(int Reason)
   {
      DeInitExpert(Reason, client); // DeInit for Expert Advisers only
      CloseClient(client);
      
      Print(StringFormat("Expert MagicNumber: %d closed with reason %s.", client.Magic, ReasonToString(Reason)));
      return 0;
   }

   virtual ~FXMindClient()
   {
      if (set != NULL)
      {
         delete set;
         set = NULL;
      }

   }
};

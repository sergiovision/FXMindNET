//+------------------------------------------------------------------+
//|                                                 ThriftClient.mqh |
//|                                                 Sergei Zhuravlev |
//|                                   http://github.com/sergiovision |
//+------------------------------------------------------------------+
#property copyright "Sergei Zhuravlev"
#property link      "http://github.com/sergiovision"
#property strict


/* Library Functions:

  //--- If the key is not found, the returned value is NULL.
  bool  GetIniKey        (string fileName, string section, string key, T &ReturnedValue)

  //---add new or update an existing key.
  bool  SetIniKey        (string fileName, string section, string key, T value)

  bool  DeleteIniKey     (string fileName, string section, string key);
  bool  DeleteIniSection (string fileName, string section);
*/

#import "kernel32.dll"
int  GetPrivateProfileStringW(string lpSection,string lpKey,string lpDefault,ushort &lpReturnedString[],int nSize,string lpFileName);
bool WritePrivateProfileStringW(string lpSection,string lpKey,string lpValue,string lpFileName);
#import

#define BUFF_SIZE 512

class SettingsFile
{
protected:
   string IniFileName;
   string IniFilePath;
   string ordersStringList[];
   int ordersTicketsList[];
public:
   string globalSection;
   SettingsFile(string globalName, string fileName)
   {
      globalSection = globalName;
      IniFileName = fileName; 
      IniFilePath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + IniFileName;
      //ordersStringList = "";
   }
   
   void SetOrdersStringList(string ordersStr, ushort sep)
   {
      int count = StringSplit(ordersStr, sep, ordersStringList);
      if (count > 0)
      {
         ushort sepOrder = StringGetCharacter("_", 0);
         ArrayResize(ordersTicketsList, count);
         string result[];
         for (int i = 0; i < count; i++)
         {
            int cnt = StringSplit(ordersStringList[i], sepOrder, result);
            if (cnt >= 2)
               ordersTicketsList[i] = (int)StringToInteger(result[1]);
         }
      }
   }
   
   void AddOrderToList(int Ticket)
   {
       if (IsTicketExistToLoad(Ticket))
         return;
       string orderSection = StringFormat("ORDER_%d", Ticket);
       int oldSize = ArraySize(ordersStringList);
       ArrayResize(ordersStringList, oldSize+1);
       ordersStringList[oldSize] = orderSection;
       ArrayResize(ordersTicketsList, oldSize+1);
       ordersTicketsList[oldSize] = Ticket;
   }
   
   bool IsTicketExistToLoad(int Ticket )
   {
       for (int i = 0; i < ArraySize(ordersTicketsList); i++)
       {
          if (ordersTicketsList[i] == Ticket)
             return true;
       }
       return false;
   }
   
   bool FileExists()
   {
      //int fileN = FileOpen(IniFilePath, FILE_READ);
      long fileN = FileIsExist(IniFileName,  FILE_COMMON);
      //fileN = FileFindFirst("/Files", IniFileName);
      if (fileN == INVALID_HANDLE)
      {
         int err = GetLastError();
         Print(StringFormat("File not exist error(%d): %s", err,IniFilePath));
         return false;
      }
      return true;
   }

//+------------------------------------------------------------------+
//| GetIniKey                                                        |
//+------------------------------------------------------------------+
/**
 * If the key is not found, the returned value is NULL.
 */
// string overload
bool GetIniKey(string section,string key,string &ReturnedValue)
  {
    
   string result=GetRawIniString(IniFilePath,section,key);

   if(StringLen(result)>0)
     {
      ReturnedValue=result;
      return (true);
     }
   else
     {
      ReturnedValue=NULL;
      return (false);
     }
  }
  
// int overload
bool GetIniKey(string section,string key,int &ReturnedValue)
  {
   string result=GetRawIniString(IniFilePath,section,key);

   if(StringLen(result)>0)
     {
      ReturnedValue=(int) StringToInteger(result);
      return (true);
     }
   else
     {
      ReturnedValue=NULL;
      return (false);
     }
  }
  
// long overload
bool GetIniKey(string section,string key,long &ReturnedValue)
  {
   string result=GetRawIniString(IniFilePath,section,key);

   if(StringLen(result)>0)
     {
      ReturnedValue=(long) StringToInteger(result);
      return (true);
     }
   else
     {
      ReturnedValue=NULL;
      return (false);
     }
  }
  
// double overload
bool GetIniKey(string section,string key,double &ReturnedValue)
  {
   string result=GetRawIniString(IniFilePath,section,key);

   if(StringLen(result)>0)
     {
      ReturnedValue=(double) StringToDouble(result);
      return (true);
     }
   else
     {
      ReturnedValue=NULL;
      return (false);
     }
  }
  
// datetime overload
bool GetIniKey(string section,string key,datetime &ReturnedValue)
  {
   string result=GetRawIniString(IniFilePath,section,key);

   if(StringLen(result)>0)
     {
      ReturnedValue=(datetime) StringToTime(result);
      return (true);
     }
   else
     {
      ReturnedValue=NULL;
      return (false);
     }
  }
  
  // bool overload
bool GetIniKey(string section,string key,bool &ReturnedValue)
  {
   string result=GetRawIniString(IniFilePath,section,key);
   if ( StringLen(result) == 0)
      return false;
   if(StringCompare(result, "true", false))
     { 
        ReturnedValue=true;
        return (true);
     }
   else
     {
        ReturnedValue=false;
        return (true);
     }
  }


  template<typename T>
  bool SetParam(string section,string key,T value)
  {
     return _setIniKey(section, key, value);
     //return (WritePrivateProfileStringW(section, key, value, IniFilePath));
  }
    
  template<typename T>
  bool SetGlobalParam(string key,T value)
  {
   return _setIniKey(globalSection, key, value);
  }
  
  // Delete better to make from C# code
  //bool DeleteSection(string section)
  //{
  // return DeleteIniSection(IniFileName, section);
  //}
  
  /*void GetAllSectionNames(string& result[])
  {
      ushort charSplitter = StringGetCharacter("\0", 0);
      //    Sets the maxsize buffer to BUFF_SIZE, if the more
      //    is required then doubles the size each time.
      for (int maxsize = BUFF_SIZE; true; maxsize*=2)
      {
          //    Obtains the information in bytes and stores
          //    them in the maxsize buffer (Bytes array)
          ushort bytes[];
          ArrayResize(bytes, maxsize);
          ArrayInitialize(bytes,0);
          int size = GetPrivateProfileStringW(NULL,"","", bytes,maxsize,IniFilePath);
          
          // Check the information obtained is not bigger
          // than the allocated maxsize buffer - 2 bytes.
          // if it is, then skip over the next section
          // so that the maxsize buffer can be doubled.
          if (size < maxsize -2)
          {
              // Converts the bytes value into an ASCII char. This is one long string.
              string Selected  = ShortArrayToString(bytes, 0, size - (size >0 ? 1:0));
              //string Selected  = CharArrayToString(bytes, 0, size - (size >0 ? 1:0));
              //string Selected = Encoding.ASCII.GetString(bytes,0, 
              //                           size - (size >0 ? 1:0));
              // Splits the Long string into an array based on the "\0"
              // or null (Newline) value and returns the value(s) in an array
              StringSplit(Selected, charSplitter, result);
              return;
          }
      }
   }*/

protected:
/**
 * add new or update an existing key.
 */
  template<typename T>
  bool _setIniKey(string section,string key,T value)
  {
   return (WritePrivateProfileStringW(section, key, (string)value, IniFilePath));
  }


//+------------------------------------------------------------------+
//| Internal function                                                |
//+------------------------------------------------------------------+
string GetRawIniString(string fileName,string section,string key)
  {
   ushort buffer[BUFF_SIZE];

   ArrayInitialize(buffer,0);
   string defaultValue="";
   GetPrivateProfileStringW(section,key,defaultValue,buffer,sizeof(buffer),fileName);
 
   return ShortArrayToString(buffer);
  }
  
  
//+------------------------------------------------------------------+
//| DeleteIniKey                                                     |
//+------------------------------------------------------------------+
bool DeleteIniKey(string fileName,string section,string key)
  {
   return (WritePrivateProfileStringW(section, key, NULL, fileName));
  }
  
//+------------------------------------------------------------------+
//| DeleteIniSection                                                 |
//+------------------------------------------------------------------+
//bool DeleteIniSection(string fileName,string section)
//  {
//   return (WritePrivateProfileStringW(section, NULL, NULL, fileName));
//  }

};
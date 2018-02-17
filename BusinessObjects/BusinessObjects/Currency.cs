/**
 * Autogenerated by Thrift Compiler (1.0.0-dev)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.IO;
using Thrift;
using Thrift.Collections;
using System.Runtime.Serialization;
using Thrift.Protocol;
using Thrift.Transport;

namespace BusinessObjects
{

  #if !SILVERLIGHT
  [Serializable]
  #endif
  public partial class Currency : TBase
  {
    private short _ID;
    private string _Name;
    private bool _Enabled;

    public short ID
    {
      get
      {
        return _ID;
      }
      set
      {
        __isset.ID = true;
        this._ID = value;
      }
    }

    public string Name
    {
      get
      {
        return _Name;
      }
      set
      {
        __isset.Name = true;
        this._Name = value;
      }
    }

    public bool Enabled
    {
      get
      {
        return _Enabled;
      }
      set
      {
        __isset.Enabled = true;
        this._Enabled = value;
      }
    }


    public Isset __isset;
    #if !SILVERLIGHT
    [Serializable]
    #endif
    public struct Isset {
      public bool ID;
      public bool Name;
      public bool Enabled;
    }

    public Currency() {
    }

    public void Read (TProtocol iprot)
    {
      TField field;
      iprot.ReadStructBegin();
      while (true)
      {
        field = iprot.ReadFieldBegin();
        if (field.Type == TType.Stop) { 
          break;
        }
        switch (field.ID)
        {
          case 1:
            if (field.Type == TType.I16) {
              ID = iprot.ReadI16();
            } else { 
              TProtocolUtil.Skip(iprot, field.Type);
            }
            break;
          case 2:
            if (field.Type == TType.String) {
              Name = iprot.ReadString();
            } else { 
              TProtocolUtil.Skip(iprot, field.Type);
            }
            break;
          case 3:
            if (field.Type == TType.Bool) {
              Enabled = iprot.ReadBool();
            } else { 
              TProtocolUtil.Skip(iprot, field.Type);
            }
            break;
          default: 
            TProtocolUtil.Skip(iprot, field.Type);
            break;
        }
        iprot.ReadFieldEnd();
      }
      iprot.ReadStructEnd();
    }

    public void Write(TProtocol oprot) {
      TStruct struc = new TStruct("Currency");
      oprot.WriteStructBegin(struc);
      TField field = new TField();
      if (__isset.ID) {
        field.Name = "ID";
        field.Type = TType.I16;
        field.ID = 1;
        oprot.WriteFieldBegin(field);
        oprot.WriteI16(ID);
        oprot.WriteFieldEnd();
      }
      if (Name != null && __isset.Name) {
        field.Name = "Name";
        field.Type = TType.String;
        field.ID = 2;
        oprot.WriteFieldBegin(field);
        oprot.WriteString(Name);
        oprot.WriteFieldEnd();
      }
      if (__isset.Enabled) {
        field.Name = "Enabled";
        field.Type = TType.Bool;
        field.ID = 3;
        oprot.WriteFieldBegin(field);
        oprot.WriteBool(Enabled);
        oprot.WriteFieldEnd();
      }
      oprot.WriteFieldStop();
      oprot.WriteStructEnd();
    }

    public override string ToString() {
      StringBuilder __sb = new StringBuilder("Currency(");
      bool __first = true;
      if (__isset.ID) {
        if(!__first) { __sb.Append(", "); }
        __first = false;
        __sb.Append("ID: ");
        __sb.Append(ID);
      }
      if (Name != null && __isset.Name) {
        if(!__first) { __sb.Append(", "); }
        __first = false;
        __sb.Append("Name: ");
        __sb.Append(Name);
      }
      if (__isset.Enabled) {
        if(!__first) { __sb.Append(", "); }
        __first = false;
        __sb.Append("Enabled: ");
        __sb.Append(Enabled);
      }
      __sb.Append(")");
      return __sb.ToString();
    }

  }

}
//+------------------------------------------------------------------+
//|                                             AutoPendingOrder.mq5 |
//|                                      Copyright 2020, NS Finanças |
//|                                    https://www.nsfinancas.com.br |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, NS Finanças"
#property link      "https://www.nsfinancas.com.br"
#property version   "1.00"
#property script_show_inputs
//---
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
//+------------------------------------------------------------------+
//| Enum pending orders DOWN                                         |
//+------------------------------------------------------------------+
enum ENUM_PENDING_ORDERS_DOWN
  {
   buy_limit         =0,   // Buy Limit
   sell_limit        =1,   // Sell Limit
   buy_stop          =2,   // Buy Stop
   sell_stop         =3    // Sell Stop
  };
//--- input parameters
input double                     InpDownGep        = 0.5;           // Diferença do preço atual (BID/ASK) para a entrada (Em PIPS)
input double                     InpDownStep       = 1;             // Distância entre ordens, caso Qty Ordens > 1 (EM PIPS)
input ENUM_PENDING_ORDERS_DOWN   InpDownOrders     = sell_stop;     // Tipo Ordem
input uchar                      InpDownQuantity   = 1;             // Qty Ordens
input double                     InpLots           = 0.01;          // Lot
input ushort                     InpStopLoss       = 2;             // Stop Loss (EM PIPS)
input ushort                     InpTakeProfit     = 3;             // Take Profit (EM PIPS)
//---
ulong                            m_slippage=30;                      // slippage
double                           m_adjusted_point;                   // point value adjusted for 3 or 5 points
double                           ExtDownGep=0.0;
double                           ExtDownStep=0.0;
double                           ExtStopLoss=0.0;
double                           ExtTakeProfit=0.0;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   if(InpLots<=0.0)
     {
      Print("The \"Lots\" can't be smaller or equal to zero");
      return;
     }
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return;
   if(!RefreshRates())
      return;

   string err_text="";
   if(!CheckVolumeValue(InpLots,err_text))
     {
      Print(err_text);
      return;
     }
//---
   if(IsFillingTypeAllowed(SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
//---
   m_trade.SetDeviationInPoints(m_slippage);
   m_trade.SetAsyncMode(true);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtDownGep     = m_adjusted_point * InpDownGep;
   ExtDownStep    = m_adjusted_point * InpDownStep;
   ExtStopLoss    = m_adjusted_point * InpStopLoss;
   ExtTakeProfit  = m_adjusted_point * InpTakeProfit;
//--- start work
   double start_price_ask=m_symbol.Ask()-ExtDownGep;
   double start_price_ask_limit=m_symbol.Ask()+ExtDownGep;
   double start_price_bid=m_symbol.Bid()-ExtDownGep;
   double start_price_bid_limit=m_symbol.Bid()+ExtDownGep;
//--- pending orders DOWN
   for(int i=0;i<InpDownQuantity;i++)
     {
      double price_ask     = start_price_ask-i*ExtDownStep;
      double price_bid     = start_price_bid-i*ExtDownStep;
      if(InpDownOrders==buy_limit)
        {
         double sl         = (ExtStopLoss==0.0)   ? 0.0 : price_ask - ExtStopLoss;
         double tp         = (ExtTakeProfit==0.0) ? 0.0 : price_ask + ExtTakeProfit;
         m_trade.BuyLimit(m_symbol.LotsMin(),m_symbol.NormalizePrice(price_ask),m_symbol.Name(),
                          m_symbol.NormalizePrice(sl),
                          m_symbol.NormalizePrice(tp));
        }
      else if(InpDownOrders==sell_stop)
        {
         double sl         = (ExtStopLoss==0.0)   ? 0.0 : price_bid + ExtStopLoss;
         double tp         = (ExtTakeProfit==0.0) ? 0.0 : price_bid - ExtTakeProfit;
         m_trade.SellStop(m_symbol.LotsMin(),m_symbol.NormalizePrice(price_bid),m_symbol.Name(),
                          m_symbol.NormalizePrice(sl),
                          m_symbol.NormalizePrice(tp));
        }
      else if(InpDownOrders==sell_limit)
        {
         price_bid = start_price_bid_limit+i*ExtDownStep;
         double sl         = (ExtStopLoss==0.0)   ? 0.0 : price_bid + ExtStopLoss;
         double tp         = (ExtTakeProfit==0.0) ? 0.0 : price_bid - ExtTakeProfit;
         m_trade.SellLimit(m_symbol.LotsMin(),m_symbol.NormalizePrice(price_bid),m_symbol.Name(),
                          m_symbol.NormalizePrice(sl),
                          m_symbol.NormalizePrice(tp));
        }
      else
        {
         price_ask     = start_price_ask_limit+i*ExtDownStep;
         double sl         = (ExtStopLoss==0.0)   ? 0.0 : price_ask - ExtStopLoss;
         double tp         = (ExtTakeProfit==0.0) ? 0.0 : price_ask + ExtTakeProfit;
         m_trade.BuyStop(m_symbol.LotsMin(),m_symbol.NormalizePrice(price_ask),m_symbol.Name(),
                          m_symbol.NormalizePrice(sl),
                          m_symbol.NormalizePrice(tp));
        }
     }
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Check the correctness of the order volume                        |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume,string &error_description)
  {
//--- minimal allowed volume for trade operations
   double min_volume=m_symbol.LotsMin();
   if(volume<min_volume)
     {
      error_description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }

//--- maximal allowed volume of trade operations
   double max_volume=m_symbol.LotsMax();
   if(volume>max_volume)
     {
      error_description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }

//--- get minimal step of volume changing
   double volume_step=m_symbol.LotsStep();

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      error_description=StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                                     volume_step,ratio*volume_step);
      return(false);
     }
   error_description="Correct volume value";
   return(true);
  }
//+------------------------------------------------------------------+ 
//| Checks if the specified filling mode is allowed                  | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes 
   int filling=m_symbol.TradeFillFlags();
//--- Return true, if mode fill_type is allowed 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+

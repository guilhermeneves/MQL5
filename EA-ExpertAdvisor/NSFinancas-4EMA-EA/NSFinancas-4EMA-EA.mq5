﻿//+------------------------------------------------------------------+
//|                                           NSFinancas-4EMA-EA.mq5 |
//|                                      Copyright 2020, NS Finanças |
//|                                    https://www.nsfinancas.com.br |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, NS Finanças"
#property link      "https://www.nsfinancas.com.br"
#property version   "1.00"

#include <Trade/SymbolInfo.mqh>

input int                  Media1         = 9;          // Média Móvel EMA1
input int                  Media2         = 13;         // Média Móvel EMA2
input int                  Media3         = 21;         // Média Móvel EMA3
input int                  Media4         = 200;        // Média Móvel EMA4 Controle Compra/Venda
input double               TP             = 0.0040;     // Take Profit referente ao preço moeda (ex: 0.0001 => 1PIP EURUSD)
input double               SL             = 0.0040;     // Stop Loss referente ao preço moeda (ex: 0.0001 => 1PIP EURUSD)
input double               Volume         = 0.02;       // Quantidade Inicial de Lot
input string               HoraInicial    = "07:00";    // Horário de Início para novas operações
input string               HoraFinal      = "19:00";    // Horário de Término para novas operações

// Painel para ordem a mercado
// CTrade myTradingControlPanel;

// Identificador do EA
int magic_number = 7894561; 

//Manipulador da media movel
int handle_media1;
int handle_media2;
int handle_media3;
int handle_media4;

//Obtem informações do ativo
CSymbolInfo simbolo; 

//Classes para roteamento de ordens
MqlTradeRequest request;
MqlTradeResult result;
MqlTradeCheckResult check_result;

// Classes para controle de tempo
MqlDateTime hora_inicial, hora_final;

// Contagem para verificação de novo candle
static int bars;

//Estrutura para representar um sinal de compra ou venda
enum ENUM_SINAL {COMPRA = 1, VENDA  = -1, NULO   = 0};


//Validação dos Inputs e inicialização do EA
int OnInit()
 {

   if(!simbolo.Name(_Symbol))
   {
      Print("Erro ao carregar o ativo.");
      return INIT_FAILED;
   }
   
   handle_media1 = iMA(_Symbol, _Period, Media1, 0, MODE_EMA, PRICE_CLOSE);
   handle_media2 = iMA(_Symbol, _Period, Media2, 0, MODE_EMA, PRICE_CLOSE);
   handle_media3 = iMA(_Symbol, _Period, Media3, 0, MODE_EMA, PRICE_CLOSE);
   handle_media4 = iMA(_Symbol, _Period, Media4, 0, MODE_EMA, PRICE_CLOSE);
   
   if (handle_media1 < 0 || handle_media2 < 0 || handle_media3 < 0 || handle_media4 < 0) 
   {
      Print("Erro ao inicializar a média móvel.");
      return INIT_FAILED;
   }
   
   if (Media1 < 0 || Media2 < 0 || Media3 < 0 || Media4 < 0 || TP < 0)
   {
      Print("Parâmetros inválidos.");
      return INIT_FAILED;
   }

   // Inicialização das variáveis de tempo
   TimeToStruct(StringToTime(HoraInicial), hora_inicial);
   TimeToStruct(StringToTime(HoraFinal), hora_final);
   
   // Verificação de inconsistências nos parâmetros de entrada
   if( (hora_inicial.hour > hora_final.hour || (hora_inicial.hour == hora_final.hour && hora_inicial.min > hora_final.min)))
   {
      Print("Os horários fornecidos estão inválidos.");
      return INIT_FAILED;
   }
   
   return(INIT_SUCCEEDED);
   
 }

//Evento invocado ao reiniciar o EA
void OnDeinit(const int reason)
 {
   printf("Reiniciando EA: %d", reason);
 }
  
//Evento invocado cada a novo tick do ativo
void OnTick()
  {

   //Atualiza os dados de cotação do ativo
   if(!simbolo.RefreshRates())
      return;

   //Verifica se há um novo candle fechado
   bool novo_candle = IsNovoCandle();
   
   if(novo_candle)
   {
   
      //Verifica se houve um sinal de compra ou venda
      ENUM_SINAL sinal = CheckSinal();
      
      //Verifica se deve abrir alguma posição de compra ou venda 
      CheckNovaEntrada(sinal);
      
      //Movimenta SL para Media2 se preço_atual > preço_entrada
      //MovimentaStopLoss2(); 
      
      //Movimenta SL para Media3 se preço_atual > preço_entrada
      //MovimentaStopLoss3(); 
      
      //Fecha Posições Abertas se preço cruzar Média3 8 candles seguidos fora
      //FechaPosicoesMedia3();
      
      //Fecha Ordens Abertas se preço cruzar Média3 8 candles seguidos fora
      //FechaOrdensMedia3();
      
      //Se horário de fechamento encerrar ordens abertas
      //if(IsHorarioFechamento()) {
      // Fechar();
      //}
      
      //Fecha Posições se posição aberta fora da Media EMA 200
      //FechaPosicoesMedia200();
        
   }
}

//Se estiver no horário permitido para novas entradas e não houver posição aberta
//É lançada uma nova ordem pendente conforme estratégia
void CheckNovaEntrada(ENUM_SINAL sinal)
 {
   // Não abre mais de 1 ordem por vez
   if(IsPosicionado() || (OrdersTotal() != 0))
      return;
   
   if (IsHorarioPermitido() && !IsPosicionado())
    {
      if (sinal == COMPRA) 
      {
         bool operacao = Comprar();      
         //bool operacao = OrdemAMercado(ORDER_TYPE_BUY, simbolo.Ask(), Volume);
         if(!operacao)
            PrintFormat("Erro!");
      }
      else if (sinal == VENDA)
      {
         bool operacao = Vender(); 
         //bool operacao = OrdemAMercado(ORDER_TYPE_SELL, simbolo.Bid(), Volume);      
         if(!operacao)
            PrintFormat("Erro!");
      }
    }
 }
 
 
//Verifica se há um novo candle fechado
bool IsNovoCandle()
 {
   if(bars != Bars(_Symbol, _Period))
    {
       bars = Bars(_Symbol, _Period);
       return true;
    }
    
   return false;
}

//Verifica se o horário atual está dentro do intervalo de tempo permitido
bool IsHorarioPermitido()
 {
   MqlDateTime hora_atual;
   TimeToStruct(TimeCurrent(), hora_atual); 
      
   if (hora_atual.hour >= hora_inicial.hour && hora_atual.hour <= hora_final.hour)
   {
      if ((hora_inicial.hour == hora_final.hour) 
            && (hora_atual.min >= hora_inicial.min) && (hora_atual.min <= hora_final.min))
         return true;
   
      if (hora_atual.hour == hora_inicial.hour)
      {
         if (hora_atual.min >= hora_inicial.min)
            return true;
         else
            return false;
      }
      
      if (hora_atual.hour == hora_final.hour)
      {
         if (hora_atual.min <= hora_final.min)
            return true;
         else
            return false;
      }
      
      return true;
   }
   
   return false;
 }

// Nova Ordem Pendente de Compra do tipo Buy Stop
bool Comprar()
{

   double preco_entrada =  simbolo.NormalizePrice(GetPrecoEntrada(COMPRA));
   double stop_loss = simbolo.NormalizePrice(preco_entrada - SL);
   double take_profit = simbolo.NormalizePrice(preco_entrada + TP);

   ZerarRequest();
   
   request.action       = TRADE_ACTION_PENDING;
   request.magic        = magic_number;
   request.symbol       = _Symbol;
   request.volume       = Volume;
   request.price        = preco_entrada; 
   request.sl           = stop_loss;
   request.tp           = take_profit;
   request.type         = ORDER_TYPE_BUY_STOP;
   request.type_filling = ORDER_FILLING_RETURN; 
   request.type_time    = ORDER_TIME_DAY;
   request.comment      = "Compra";
   
   return EnviarRequisicao();
   
   
}

// Nova Ordem Pendente de Venda do tipo Sell Stop

bool Vender()
{

   double preco_entrada = simbolo.NormalizePrice(GetPrecoEntrada(VENDA));
   double stop_loss = simbolo.NormalizePrice(preco_entrada + SL); 
   double take_profit = simbolo.NormalizePrice(preco_entrada - TP); 
   
   ZerarRequest();
   
   request.action       = TRADE_ACTION_PENDING;
   request.magic        = magic_number;
   request.symbol       = _Symbol;
   request.volume       = Volume;
   request.price        = preco_entrada; 
   request.sl           = stop_loss;
   request.tp           = take_profit;
   request.type         = ORDER_TYPE_SELL_STOP;
   request.type_filling = ORDER_FILLING_RETURN; 
   request.type_time    = ORDER_TIME_DAY;
   request.comment      = "Venda";
   
   return EnviarRequisicao();

} 

// Envio de Ordem a Mercado Utilizando Trade.mqh
bool OrdemAMercado(ENUM_ORDER_TYPE tipo, double preco, double volume)
{
   double currentBid = SymbolInfoDouble(_Symbol,SYMBOL_BID); // Get latest Bid Price
   double currentAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK); // Get latest Ask Price
   double stopLossLevel; 
   double takeProfitLevel; 
   if(tipo == ORDER_TYPE_BUY_STOP) {
      stopLossLevel = simbolo.NormalizePrice(preco - TP); 
      takeProfitLevel = simbolo.NormalizePrice(preco + TP); 
   } else {
      stopLossLevel = simbolo.NormalizePrice(preco + TP); 
      takeProfitLevel = simbolo.NormalizePrice(preco - TP); 
   }
   
   // myTradingControlPanel.PositionOpen(_Symbol, tipo, volume, currentAsk, stopLossLevel, takeProfitLevel, "Buy Trade. Magic Number #" + (string) myTradingControlPanel.RequestMagic()); // Open a Buy position
   
   return true;
}


//Verifica se há ordens pendentes ou posições abertas e as fecha imediatamente
void Fechar()
{  
   FecharOrdens();
   
   FecharPosicao();
}

//Fecha ordens abertas
void FecharOrdens()
 {
   if(OrdersTotal() != 0)
   {
      for(int i=OrdersTotal()-1; i>=0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL)==_Symbol)
         {
            ZerarRequest();
            
            request.action       = TRADE_ACTION_REMOVE;
            request.order        = ticket;
            request.comment      = "Removendo ordem";
            
            EnviarRequisicao();
         }
      }
   }
 }
 
//Fecha posições abertas
void FecharPosicao()
 {
   if(IsPosicionado())
		{
      
      ZerarRequest();
      
      //double volume_operacao = PositionGetDouble(POSITION_VOLUME);
      
      request.action       = TRADE_ACTION_DEAL;
      request.magic        = magic_number;
      request.symbol       = _Symbol;
      request.volume       = Volume;
      request.deviation = 5;
      request.position  = PositionGetInteger(POSITION_TICKET);
      request.type_filling = ORDER_FILLING_IOC; 
      request.comment      = "Fechando posição";
         
      long tipo = PositionGetInteger(POSITION_TYPE);
      // ENUM_POSITION_TYPE tipo=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);  // type of the position
      if(tipo == POSITION_TYPE_BUY)
      {
         request.price = simbolo.Bid(); 
         request.type = ORDER_TYPE_SELL;
      }
      else
      {
         request.price = simbolo.Ask(); 
         request.type = ORDER_TYPE_BUY;
      }
      EnviarRequisicao();
    }
 }
 
//Limpa estrutura de requisição de roteamento
void ZerarRequest()
 {
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check_result);
 }
 
//Valida e envia requisição de roteamento
bool EnviarRequisicao()
 {
   ResetLastError();
   
   PrintFormat("Request - %s, VOLUME: %.2f, PRICE: %.4f, SL: %.4f, TP: %.4f", request.comment, request.volume, request.price, request.sl, request.tp);
   if(!OrderCheck(request, check_result))
   {
      //PrintFormat("Erro em OrderCheck: %d - Código: %d", GetLastError(), check_result.retcode);
      PrintFormat("Request - %s, VOLUME: %.2f, PRICE: %.4f, SL: %.4f, TP: %.4f", request.comment, request.volume, request.price, request.sl, request.tp);
      return false;
   }
   
   if(!OrderSend(request, result))
   {
      PrintFormat("Erro em OrderSend: %d - Código: %d", GetLastError(), result.retcode);
      return false;
   }
   return true;
 }

//Verifica se há um novo sinal de compra ou venda da estratégia 3EMA

ENUM_SINAL CheckSinal()
 {
   double media1_buffer[];
   double media2_buffer[];
   double media3_buffer[];
   double media4_buffer[];
   
   CopyBuffer(handle_media1, 0, 0, 6, media1_buffer);
   CopyBuffer(handle_media2, 0, 0, 6, media2_buffer);
   CopyBuffer(handle_media3, 0, 0, 6, media3_buffer);
   CopyBuffer(handle_media4, 0, 0, 6, media4_buffer);
   ArraySetAsSeries(media1_buffer, true);
   ArraySetAsSeries(media2_buffer, true);
   ArraySetAsSeries(media3_buffer, true);
   ArraySetAsSeries(media4_buffer, true);
   
   MqlRates PriceDataTable[];
   ArraySetAsSeries(PriceDataTable,true);
   CopyRates(_Symbol,0,0,10,PriceDataTable);
   
   //bool TEMA_trigger_sell = PriceDataTable[1].high > media1_buffer[1] && PriceDataTable[1].high < media2_buffer[1] &&
   //                         PriceDataTable[1].high < media3_buffer[1];
   bool TEMA_trigger_sell = PriceDataTable[1].high > media1_buffer[1];
                      
   bool last_4_candles_sell = PriceDataTable[2].high < media1_buffer[2] && PriceDataTable[3].high < media1_buffer[3] &&
                             PriceDataTable[4].high < media1_buffer[4] && PriceDataTable[5].high < media1_buffer[5];
                             
   //bool TEMA_trigger_buy = PriceDataTable[1].low < media1_buffer[1] && PriceDataTable[1].low > media2_buffer[1]
   //                   && PriceDataTable[1].low > media3_buffer[1];
   bool TEMA_trigger_buy = PriceDataTable[1].low < media1_buffer[1];
                      
   bool last_4_candles_buy = PriceDataTable[2].low > media1_buffer[2] && PriceDataTable[3].low > media1_buffer[3] &&
                             PriceDataTable[4].low > media1_buffer[4] && PriceDataTable[5].low > media1_buffer[5];
   
   bool isBuy = PriceDataTable[0].low > media4_buffer[0] && PriceDataTable[1].low > media4_buffer[1] &&
                PriceDataTable[2].low > media4_buffer[2] && PriceDataTable[3].low > media4_buffer[3] &&
                PriceDataTable[4].low > media4_buffer[4];
   
   bool isSell = PriceDataTable[0].high < media4_buffer[0] && PriceDataTable[1].high < media4_buffer[1] &&
                 PriceDataTable[2].high < media4_buffer[2] && PriceDataTable[3].high < media4_buffer[3] &&
                 PriceDataTable[4].high < media4_buffer[4];
                     
   
   if (TEMA_trigger_buy && last_4_candles_buy && isBuy) {
      return COMPRA;
   }
   
   if (TEMA_trigger_sell && last_4_candles_sell && isSell) {
      return VENDA;
   }
   
   return NULO;
 }
 
//Obtem o preço de entrada para compra ou venda

double GetPrecoEntrada(ENUM_SINAL sinal)
 {
   MqlRates PriceDataTable[];
   ArraySetAsSeries(PriceDataTable,true);
   CopyRates(_Symbol,0,0,10,PriceDataTable);
   
   double max_open_close = 0;
   double min_open_close = 10000;
   
   for(int x=1; x<=5; x++) {
      if(max_open_close < PriceDataTable[x].open) {
         max_open_close = PriceDataTable[x].open;
      }
      if(min_open_close > PriceDataTable[x].open) {
         min_open_close = PriceDataTable[x].open;
      }
      if(max_open_close < PriceDataTable[x].close) {
         max_open_close = PriceDataTable[x].close;
      }
      if(min_open_close > PriceDataTable[x].close) {
         min_open_close = PriceDataTable[x].close;
      }
   }
   
   if (sinal == COMPRA)
      return max_open_close;
         
   if (sinal == VENDA)
      return min_open_close;
   
   return -1;
 }

//Verifica se há posição no ativo
bool IsPosicionado()
 {  
   bool IsPosicionado=PositionGetTicket(0)>0;
   return IsPosicionado;
 }
 
 
 //Altera o stop loss de uma posição aberta para o novo ponto de saída
void MovimentaStopLoss2() 
 {
   if(IsPosicionado())
		{
         double media2_buffer[];
      
         CopyBuffer(handle_media2, 0, 0, 6, media2_buffer);
         ArraySetAsSeries(media2_buffer, true);
         
         bool changeSL = false;
         bool FatorMovSL = true;
         double stop_loss_mv;
         double take_profit_mv;
         
         if(request.type == ORDER_TYPE_BUY) {
            changeSL = (media2_buffer[1]) > request.price;
            FatorMovSL = (media2_buffer[1] - request.price) < SL;
            stop_loss_mv = media2_buffer[1] - SL;
            take_profit_mv = request.price + (3*TP);
         } else {
            changeSL = (media2_buffer[1]) < request.price;
            FatorMovSL = (request.price - media2_buffer[1]) < SL;
            stop_loss_mv = media2_buffer[1] + SL;
            take_profit_mv = request.price - (3*TP);
         }
         
         if(changeSL && FatorMovSL) {
           
            ZerarRequest();
         
            request.action    = TRADE_ACTION_SLTP;                          
            request.magic     = magic_number;                                           
            request.symbol    = _Symbol;                                  
            request.sl        = stop_loss_mv; 
            request.tp        = take_profit_mv;                                    
            request.position  = PositionGetInteger(POSITION_TICKET);
            request.comment   = "Alterando Stop Loss";
            request.type_time = ORDER_TIME_DAY;
           
             EnviarRequisicao();
         }
         
         if(!FatorMovSL){
            ZerarRequest();
         
            request.action    = TRADE_ACTION_SLTP;                          
            request.magic     = magic_number;                                           
            request.symbol    = _Symbol;                                  
            request.sl        = media2_buffer[1]; 
            request.tp        = 0;                                    
            request.position  = PositionGetInteger(POSITION_TICKET);
            request.comment   = "Alterando Stop Loss";
            request.type_time = ORDER_TIME_DAY;
           
            EnviarRequisicao();
         }
      }   
 }
 
 //Altera o stop loss de uma posição aberta para o novo ponto de saída
void MovimentaStopLoss3()
 {
   if(IsPosicionado()) {

      double media3_buffer[];
   
      CopyBuffer(handle_media3, 0, 0, 6, media3_buffer);
      ArraySetAsSeries(media3_buffer, true);
      
      bool changeSL = false;
      bool FatorMovSL = true;
      double stop_loss_mv;
      double take_profit_mv;
      
      if(request.type == ORDER_TYPE_BUY) {
         changeSL = (media3_buffer[1]) > request.price;
         //FatorMovSL = (media3_buffer[1] - request.price) < SL;
         stop_loss_mv = media3_buffer[1] - SL;
         take_profit_mv = request.price + (3*TP);
      } else {
         changeSL = (media3_buffer[1]) < request.price;
         FatorMovSL = (request.price - media3_buffer[1]) < SL;
         stop_loss_mv = media3_buffer[1] + SL;
         take_profit_mv = request.price - (3*TP);
      }
      
      if(changeSL && FatorMovSL) {
        
         ZerarRequest();
      
         request.action    = TRADE_ACTION_SLTP;                          
         request.magic     = magic_number;                                           
         request.symbol    = _Symbol;                                  
         request.sl        = stop_loss_mv; 
         request.tp        = take_profit_mv;                                    
         request.position  = PositionGetInteger(POSITION_TICKET);
         request.comment   = "Alterando Stop Loss";
         request.type_time = ORDER_TIME_DAY;
        
         EnviarRequisicao();
      }
      
      if(!FatorMovSL){
         ZerarRequest();
      
         request.action    = TRADE_ACTION_SLTP;                          
         request.magic     = magic_number;                                           
         request.symbol    = _Symbol;                                  
         request.sl        = media3_buffer[1]; 
         request.tp        = 0;                                    
         request.position  = PositionGetInteger(POSITION_TICKET);
         request.comment   = "Alterando Stop Loss";
         request.type_time = ORDER_TIME_DAY;
        
         EnviarRequisicao();
      }
   
   }  
 }
 
 // Avalia se ultimos 8 candles ultrapassaram 3 Media Movel
 void FechaPosicoesMedia3() {

   double media3_buffer[];
   double media4_buffer[];
   
   CopyBuffer(handle_media3, 0, 0, 15, media3_buffer);
   CopyBuffer(handle_media4, 0, 0, 15, media4_buffer);
   
   ArraySetAsSeries(media3_buffer, true);
   ArraySetAsSeries(media4_buffer, true);
   
   MqlRates PriceDataTable[];
   ArraySetAsSeries(PriceDataTable,true);
   CopyRates(_Symbol,0,0,15,PriceDataTable);
   
   
   //if(!PositionSelect(_Symbol))
   //   return;
   if(IsPosicionado())
   {      
      long tipo = PositionGetInteger(POSITION_TYPE);   
      
      //bool isBuy = PriceDataTable[1].low > media4_buffer[1];
      bool isBuy  =  tipo == POSITION_TYPE_BUY;
      //bool isSell = PriceDataTable[1].high < media4_buffer[1];
      bool isSell = tipo == POSITION_TYPE_SELL;
      
      bool candlesForaMedia3Buy = PriceDataTable[1].low < media3_buffer[1] &&
                                  PriceDataTable[2].low < media3_buffer[2] &&
                                  PriceDataTable[3].low < media3_buffer[3] &&
                                  PriceDataTable[4].low < media3_buffer[4] &&
                                  PriceDataTable[5].low < media3_buffer[5] &&
                                  PriceDataTable[6].low < media3_buffer[6] &&
                                  PriceDataTable[7].low < media3_buffer[7] &&
                                  PriceDataTable[8].low < media3_buffer[8];
   
       
      bool candlesForaMedia3Sell = PriceDataTable[1].high > media3_buffer[1] &&
                                  PriceDataTable[2].high > media3_buffer[2] &&
                                  PriceDataTable[3].high > media3_buffer[3] &&
                                  PriceDataTable[4].high > media3_buffer[4] &&
                                  PriceDataTable[5].high > media3_buffer[5] &&
                                  PriceDataTable[6].high > media3_buffer[6] &&
                                  PriceDataTable[7].high > media3_buffer[7] &&
                                  PriceDataTable[8].high > media3_buffer[8];
   
      if(isBuy) {
         if(candlesForaMedia3Buy) {
            Fechar();
         }
      }
      
      if(isSell) {
         if(candlesForaMedia3Sell) {
            Fechar();  
         }
      }
   }
 }
 
 
 // Avalia se ultimos 8 candles ultrapassaram 3 Media Movel
 void FechaOrdensMedia3() {

   double media3_buffer[];
   double media4_buffer[];
   
   CopyBuffer(handle_media3, 0, 0, 15, media3_buffer);
   CopyBuffer(handle_media4, 0, 0, 15, media4_buffer);
   
   ArraySetAsSeries(media3_buffer, true);
   ArraySetAsSeries(media4_buffer, true);
   
   MqlRates PriceDataTable[];
   ArraySetAsSeries(PriceDataTable,true);
   CopyRates(_Symbol,0,0,15,PriceDataTable);
   
   if(OrdersTotal() != 0)
   {   
      bool candlesForaMedia3Buy = PriceDataTable[1].low < media3_buffer[1] &&
                                  PriceDataTable[2].low < media3_buffer[2] &&
                                  PriceDataTable[3].low < media3_buffer[3] &&
                                  PriceDataTable[4].low < media3_buffer[4] &&
                                  PriceDataTable[5].low < media3_buffer[5] &&
                                  PriceDataTable[6].low < media3_buffer[6] &&
                                  PriceDataTable[7].low < media3_buffer[7] &&
                                  PriceDataTable[8].low < media3_buffer[8];
   
       
      bool candlesForaMedia3Sell = PriceDataTable[1].high > media3_buffer[1] &&
                                  PriceDataTable[2].high > media3_buffer[2] &&
                                  PriceDataTable[3].high > media3_buffer[3] &&
                                  PriceDataTable[4].high > media3_buffer[4] &&
                                  PriceDataTable[5].high > media3_buffer[5] &&
                                  PriceDataTable[6].high > media3_buffer[6] &&
                                  PriceDataTable[7].high > media3_buffer[7] &&
                                  PriceDataTable[8].high > media3_buffer[8];
      ulong ticket;
      ticket = OrderGetTicket(0);
      string type = EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
      bool isBuy = type == EnumToString(ORDER_TYPE_BUY_STOP);
      
      if(isBuy && candlesForaMedia3Buy) {
         Fechar();
      } else if (!isBuy && candlesForaMedia3Sell) {
         Fechar();
      }
   }
 }

//Verifica se o horário limite para operações foi alcançado
bool IsHorarioFechamento()
 {
   MqlDateTime hora_atual;
   TimeToStruct(TimeCurrent(), hora_atual); 
   
   if (hora_atual.hour > hora_final.hour) {
      return true;
   }
   if ((hora_atual.hour == hora_final.hour) && (hora_atual.min >= hora_final.min)) {
      return true;
   }
   return false;
 }
 
 // Utilizando Média Móvel EMA 200 como SL
 void FechaPosicoesMedia200() {

   double media4_buffer[];
   
   CopyBuffer(handle_media4, 0, 0, 2, media4_buffer);
   
   ArraySetAsSeries(media4_buffer, true);
   
   MqlRates PriceDataTable[];
   ArraySetAsSeries(PriceDataTable,true);
   CopyRates(_Symbol,0,0,2,PriceDataTable);
   
   
   if(IsPosicionado())
		{
      
      long tipo = PositionGetInteger(POSITION_TYPE);   
      
      //bool isBuy = PriceDataTable[1].low > media4_buffer[1];
      bool isBuy  =  tipo == POSITION_TYPE_BUY;
      //bool isSell = PriceDataTable[1].high < media4_buffer[1];
      bool isSell = tipo == POSITION_TYPE_SELL;
      
      bool candlesForaMedia200Buy = PriceDataTable[1].low < (media4_buffer[1]-(SL/2));
   
      bool candlesForaMedia200Sell = PriceDataTable[1].high > (media4_buffer[1]+(SL/2));
   
   
      if(isBuy) {
         if(candlesForaMedia200Buy) {
            Fechar();
         }
      }
      
      if(isSell) {
         if(candlesForaMedia200Sell) {
            Fechar();  
         }
      }
      
   }
 }
 

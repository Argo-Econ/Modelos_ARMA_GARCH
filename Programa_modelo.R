#------------------------------------------------------------------------------#
# Desarrollo de la met. Box Jenkings ----
## Modelos ARIMA media condicional
## Modelo GARCH para la volatilidad
## Arturo Yesid Gonzalez ----
# ***************************************************************************** ----

# carga de librerias (funciones para el desarrollo practico)
require(pacman) # library(pacman)

p_load(readxl, sandwich, car, lmtest, TSstudio, lmtest, forecast
       , tseries, TSA, tsoutliers, GGally, xts, ggplot2, dplyr
       , MASS, nortest, tsoutliers, nortest, FinTS, rugarch)


# Importacion datos ----
#------------------------------------------------------------------------------#
Datos_ent1 <- read_xlsx(path = "Datos_ent/Bases_Modelos_P38.xlsx"
                        ,sheet = "Acciones",range = "a4:bm394"
                        ,col_names = T)

tail(Datos_ent1)

Datos_ent2 <- read_xlsx(path = "Datos_ent/Bases_Modelos_P38.xlsx"
                        ,sheet = "Exogenas",range = "a3:d411"
                        ,col_names = T)
tail(Datos_ent2)

# Definicion de objetos de serie de tiempo ----
#------------------------------------------------------------------------------#

# Acciones - variables de interes
Datos_ent1_ts1 <- ts(Datos_ent1[,-1],start = c(1990,1),frequency = 12)
Datos_ent1_ts2 <- xts(Datos_ent1[,-1]
                      ,order.by = as.Date(Datos_ent1$Fecha))

# Exogenas
Datos_ent2_ts1 <- ts(Datos_ent2[,-1],start = c(1990,1),frequency = 12)
Datos_ent2_ts2 <- xts(Datos_ent2[,-1]
                      ,order.by = as.Date(Datos_ent2$Fecha))

## Creacion de la base de modelacion ----
#------------------------------------------------------------------------------#

# Objeto ts
Base_modelo_ts <- ts.union(Datos_ent1_ts1[,4],Datos_ent2_ts1)
tail(Base_modelo_ts)
colnames(Base_modelo_ts) <- c("Chile","Brent","IP_Index","IPC_EEUU")
View(Base_modelo_ts)

Base_exo_pronos_ts <- tail(Base_modelo_ts[,-1],19)

Base_modelo_dep_ts <- Base_modelo_ts %>% na.omit()
head(Base_modelo_dep_ts)
tail(Base_modelo_dep_ts)  

# Base modelo con objetos xts (reto)
Base_modelo_xts <- cbind.xts(Datos_ent1_ts2[,4],Datos_ent2_ts2)
tail(Base_modelo_xts)
colnames(Base_modelo_xts) <- c("Chile","Brent","IP_Index","IPC_EEUU")
View(Base_modelo_xts)

Base_exo_pronos_xts <- tail(Base_modelo_xts[,-1],19)

Base_modelo_dep_xts <- Base_modelo_xts %>% na.omit()
head(Base_modelo_dep_xts)
tail(Base_modelo_dep_xts)  



# Especificación ----

## Elementos gráficos
#------------------------------------------------------------------------------#
ts_plot(Base_modelo_dep_ts
        ,type = "multiple"
        ,slider = T)

ts_plot(Base_modelo_dep_xts
        ,type = "multiple"
        ,slider = T)

# Comportamiento estacional de la variable objetivo
ts_seasonal(Base_modelo_dep_xts$Chile, type = "all")
ts_cor(Base_modelo_dep_xts$Chile, lag.max = 60) # con objetos xts no funciona
ts_cor(Base_modelo_dep_ts[,1], lag.max = 60)    # funciona con objetos ts


windows()
tsdisplay(Base_modelo_dep_ts[,1], main = "Indice accionario Chile"
          , xlab = "Fecha", ylab = "IPSA")

ts_lags(Base_modelo_dep_ts[,1], lags = 1:18)
ts_lags(Base_modelo_dep_xts$Chile, lags = 1:18)



## Transformación Box-Cox ----
#------------------------------------------------------------------------------#

boxCox(lm(Base_modelo_dep_xts$Chile~1),    # regresión var. de interes como regresor constante
       lambda = seq(-3, 3, 1/100), # secuencia de valores para lambda
       plotit = TRUE,  # Crear el emento grafico de contraste
       eps = 1/50,     # tolerancia sobre valor de lambda
       xlab = expression(lambda), # Valores para lambda
       ylab = "log-Likelihood",
       main ="Valor de lambda")

lambda_chile <- BoxCox.lambda(Base_modelo_dep_xts$Chile, method = "loglik")
lambda_Brent <- BoxCox.lambda(Base_modelo_dep_xts$Brent, method = "loglik")
lambda_IP_index <- BoxCox.lambda(Base_modelo_dep_xts$IP_Index, method = "loglik")
lambda_IPC_EEUU <- BoxCox.lambda(Base_modelo_dep_xts$IPC_EEUU, method = "loglik")

# forma optima
lamdas_buff <- apply(Base_modelo_dep_xts, 2, function(x)  BoxCox.lambda(x,method = "loglik") )


# serie_transformada Box-Cox manual
Chile_BoxCox <- BoxCox(Base_modelo_dep_xts$Chile,lambda = lambda_chile)
Brent_BoxCox <- BoxCox(Base_modelo_dep_xts$Brent,lambda = lambda_Brent)
IP_Index_BoxCox <- BoxCox(Base_modelo_dep_xts$IP_Index,lambda = lambda_IP_index)
IPC_EEUU_BoxCox <- BoxCox(Base_modelo_dep_xts$IPC_EEUU,lambda = lambda_IPC_EEUU)

Base_modelo_dep_xts_BoxCox <- cbind.xts(Base_modelo_dep_xts,Chile_BoxCox$Chile
                                 ,Brent_BoxCox$Brent,IP_Index_BoxCox$IP_Index
                                 ,IPC_EEUU_BoxCox$IPC_EEUU)

names(Base_modelo_dep_xts_BoxCox)
colnames(Base_modelo_dep_xts_BoxCox) <- c("Chile","Brent","IP_Index","IPC_EEUU"
                                          ,"Chile_BoxCox","Brent_BoxCox"
                                          ,"IP_Index_BoxCox","IPC_EEUU_BoxCox")

tail(Base_modelo_dep_xts_BoxCox)
# variable IP_Index se transformó para mal ¿?

# forma optima
Base_modelo_dep_xts_bx <- apply(Base_modelo_dep_xts
                                , 2, function(y) BoxCox(y
                                                        ,BoxCox.lambda(y,method = "loglik")) )


# Mensajes:
# la transformación en BoxCox debe mirar se con cuidado evaluando su ajuste
# entérminos de la varianza.
# Mayor detalle ver: https://onlinestatbook.com/2/transformations/box-cox.html
# -----------------------------------------------------------------------------#

# Se perdió el atributo de serie de tiempo al efectuar transformación optima
class(Base_modelo_dep_xts_bx)
head(Base_modelo_dep_xts)

f_ini <- as.Date("1993-09-01")
f_end <- as.Date("2022-06-1")
fechas <- seq(f_ini, f_end, by = "month")

Base_modelo_dep_xts_bx <- xts(Base_modelo_dep_xts_bx,order.by = fechas)
tail(Base_modelo_dep_xts_bx)

ts_plot(Base_modelo_dep_xts_bx
        ,type = "multiple"
        ,slider = T
        ,title = "Base con transformación BoxCox")



# la transformacion Box Cox atenua la varianza
var(Base_modelo_dep_xts[,1])
var(Base_modelo_dep_xts_bx[,1])

# Comprobar que la serie se estacionaria (prueba de raiz unitaria)
adf.test(Base_modelo_dep_xts[,1]) # sobre el indice de chile la H0 no se rechaza
adf.test(Base_modelo_dep_xts_bx[,1]) # sobre chile boxcox h0 no se rechaza


# aplicar diferencias a la informacion
Base_modelo_dep_xts_bx_diff <- Base_modelo_dep_xts_bx %>% diff() %>% na.omit()
tail(Base_modelo_dep_xts_bx_diff)


# vuelo a testear estacionariedad
adf.test(Base_modelo_dep_xts_bx_diff[,1]) # Se rechaza H0 -> serie estacionaria I(1)
                                          # se aplicó una diferencia, entonces d=1
kpss.test(Base_modelo_dep_xts_bx_diff[,1]) # H0: serie estacionaria
pp.test(Base_modelo_dep_xts_bx_diff[,1])   # H0: serie no estacionaria


## Transformación retornos log ----
# -----------------------------------------------------------------------------#

Base_modelo_dep_ts_dlx <- Base_modelo_dep_ts %>% log() %>% diff()
#Base_modelo_dep_ts_dlx <- diff(log(Base_modelo_dep_ts))

# probar estacionariedad
adf.test(Base_modelo_dep_ts_dlx[,1])  # Rechaza H0
kpss.test(Base_modelo_dep_ts_dlx[,1]) # No Rechaza H0
pp.test(Base_modelo_dep_ts_dlx[,1])   # Rechaza H0

# -----------------------------------------------------------------------------#
# 1. que puedo aplicar transformaciones BoxCox para estabilizar
#    la varianza, y aplicar la diferencia para estabilizar 
#    la tendencia o media de la serie
# 2. valor del parametro d=? es uno porque se aplicó una diferencia para
#    convertir la serie en estacionaria

# atajo tanto para diferencias directas como diferencias estacionales
ndiffs(Base_modelo_dep_ts[,1]) # el numero d para colocarlo en el modelo ARIMA(p,d,q)
nsdiffs(Base_modelo_dep_ts[,1])

# -----------------------------------------------------------#
# Segundo paso en la identificacion (graficos de FAC y PACF)
# estructura AR y MA

windows()
tsdisplay(Base_modelo_dep_ts_dlx[,1])
# posible modelo AR=1


grafico1 <- autoplot(Base_modelo_dep_ts[,1]) +ylab("indice")+xlab("fecha")
grafico2 <- autoplot(Base_modelo_dep_ts_dlx[,1]) +ylab("retornos")+xlab("fecha")
grafico3 <- Acf(Base_modelo_dep_ts[,1]) %>% autoplot() + labs(x='rezago'
                                                          ,y='FAC serie original')
grafico4 <- Pacf(Base_modelo_dep_ts[,1]) %>% autoplot() + labs(x='rezago'
                                                           ,y='FACP serie original')
grafico5 <- Acf(Base_modelo_dep_ts_dlx[,1]) %>% autoplot() + labs(x='rezago'
                                                          ,y='FAC serie en retornos')
grafico6 <- Pacf(Base_modelo_dep_ts_dlx[,1]) %>% autoplot() + labs(x='rezago'
                                                           ,y='FACP serie en retornos')
windows()
gridExtra::grid.arrange(grafico1,grafico3
                        ,grafico4,grafico2
                        ,grafico5,grafico6,
                        ncol=3)

eacf(Base_modelo_dep_ts_dlx[,1],ar.max = 10, ma.max = 10)


# Conclusion:
# 1. existen unos posibles modelos a estimar
#     MA(1), ARMA(1,1), ARMA(1,2)



# Estimacion modelos -----
# -----------------------------------------------------------------------------#

## modelo 1 ----
mod1 <- Arima(y = Base_modelo_dep_ts_dlx[,1],order = c(0,0,1))
summary(mod1)


## Carga de función eval residuales ----
source("Funciones/Funcion_Prueba_Residuales.r")

### Chequeo mod1 ----
windows()
checkresiduals(mod1)

windows()
prueba_residuales(mod1$residuals)

## modelo 2 ----
mod2 <- Arima(y = Base_modelo_dep_ts_dlx[,1],order = c(1,0,2))
summary(mod2)

### Chequeo mod2 ----
windows()
checkresiduals(mod2)

windows()
prueba_residuales(mod2$residuals)


## modelo 3 con exogenas ----
mod3 <- Arima(y = Base_modelo_dep_ts_dlx[,1],order = c(1,0,2)
              ,xreg = Base_modelo_dep_ts_dlx[,-1])
summary(mod3)

### Chequeo mod3 con exogenas ----
windows()
checkresiduals(mod3)

windows()
prueba_residuales(mod3$residuals)


## modelo 4 niveles y exogenas ----
mod4 <- Arima(y = log(Base_modelo_dep_ts[,1]),order = c(1,1,2)
              ,xreg = log(Base_modelo_dep_ts[,-1]))
summary(mod4)

### Chequeo mod4 niveles y exogenas ----
windows()
checkresiduals(mod4)

windows()
prueba_residuales(mod4$residuals)


## modelo 5 ajuste manual ----
mod5 <- Arima(y = log(Base_modelo_dep_ts[,1]),order = c(1,1,2)
              ,seasonal = c(1,0,1)
              ,xreg = log(Base_modelo_dep_ts[,-1]))
summary(mod5)

### Chequeo modelo 5 ajuste ----
windows()
checkresiduals(mod5)

windows()
prueba_residuales(mod5$residuals)


## modelo 6 auto.arima en lx ----
mod6 <- auto.arima(y = log(Base_modelo_dep_ts[,1])
                   ,d = 1,max.order = 14,start.p = 2
                   ,trace = T,stepwise = F
                   ,xreg = log(Base_modelo_dep_ts[,-1]))
summary(mod6)

### Chequeo modelo auto.arima en lx ----
windows()
checkresiduals(mod6)

windows()
prueba_residuales(mod6$residuals)


# Mensaje,
# En terminos de la varianza los modelos son pobres, hay outliers 
# por corregir


# Analisis de intervencion ----
# Detección de outliers
# tipos de outliers
# -----------------------------------------------------------------------------#

# - Additive outliers (AO)      - función pulso
# - Level Shift       (LS)
# - Transient change  (TC)      - Cambio de nivel
# - Innovation Ouliers (IO)     - Cambio progresivo
# - Seasonal level Shifts (SLS)

ts_plot(log(Base_modelo_dep_ts[,1]))

outliers_chile <- tso(log(Base_modelo_dep_ts[,1])
                    , types = c("TC", "AO", "LS") )
windows()
plot(outliers_chile)

## Ejemplos outliers ----
tc <- rep(0, nrow(log(Base_modelo_dep_ts)))
tc[319] <- 0.215

# cambio de nivel
ls <- stats::filter(tc, filter = 1, method = "recursive")
plot(ls)

# pulso
ao <- stats::filter(tc, filter = 0, method = "recursive")
ts_plot(ao)

# Cambio temporal - tracendente
tc_0_4 <- stats::filter(tc, filter = 0.4, method = "recursive")
tc_0_8 <- stats::filter(tc, filter = 0.8, method = "recursive")
tc_all <- cbind("TC_delta_0.4"= tc_0_4, "TC_delta_0.8"= tc_0_8)

ts_plot(tc_all, title = "Cambio transitorio")



# Outliers con serie de trabajo ----
outliers_chile
outliers_chile$outliers$coefhat

# Fechas en las que ocurrieron los outlier
outliers_idx <- outliers_chile$outliers$ind

# Creación de los outliers
n <- length(Base_modelo_dep_ts[,1])
outlier1_tc1 <- outliers("TC", outliers_idx[1])
outlier2_tc2 <- outliers("TC", outliers_idx[2])

outlier1_tc <- outliers.effects(outlier1_tc1, n)
outlier2_tc <- outliers.effects(outlier2_tc2, n)

# Unión de las series de outliers
outliers_gral <- cbind(outlier1_tc,outlier2_tc)
ts_plot(as.ts(outliers_gral), type="multiple")

# Visualización de serie original y de la intervención
comparativo <- cbind("Intervenida"=outliers_chile$yadj,"Original"=log(Base_modelo_dep_ts[,1]))
ts_plot(as.ts(comparativo))

# /------ fin intervencion --------------------------------------------

head(Base_modelo_dep_ts)
Chile_interv <- ts(outliers_chile$yadj, start = c(1993,9)
                   ,frequency = 12)

Base_modelo_dep_ts_log <- ts.union(log(Base_modelo_dep_ts),Chile_interv)
View(Base_modelo_dep_ts_log)

colnames(Base_modelo_dep_ts_log) <- c("Chile","Brent","IP_Index"
                                      ,"IPC_EEUU","Chile_interv")


## modelo 7 intervenida ----
mod7 <- auto.arima(y = Base_modelo_dep_ts_log[,5]
                   ,d = 1,max.order = 14,start.p = 2
                   ,trace = T,stepwise = F, allowdrift = F
                   ,xreg = Base_modelo_dep_ts_log[,c(-1,-5)])
summary(mod7)

### Chequeo modelo auto.arima en lx ----
windows()
checkresiduals(mod7)

windows()
prueba_residuales(mod7$residuals)


# Pronostico (Uso del modelos) -----
# -----------------------------------------------------------------------------#


## Pronosticos libres sin exogenas ----
fore_mod1 <- forecast(mod1, h=19)
autoplot(fore_mod1)

fore_mod2 <- forecast(mod2, h=19)
autoplot(fore_mod2)


## Pronosticos con exogenas ----
Base_exo_pronos_ts
fore_mod3 <- forecast(mod3, xreg = diff(log(Base_exo_pronos_ts)))
autoplot(fore_mod3)

fore_mod4 <- forecast(mod4, xreg = log(Base_exo_pronos_ts))
autoplot(fore_mod4)

fore_mod5 <- forecast(mod5, xreg = log(Base_exo_pronos_ts))
autoplot(fore_mod5)

fore_mod6 <- forecast(mod6, xreg = log(Base_exo_pronos_ts))
autoplot(fore_mod6)

fore_mod7 <- forecast(mod7, xreg = log(Base_exo_pronos_ts))
autoplot(fore_mod7)


# /------------------------------------------------------------------  ---- 



# -----------------------------------------------------------------------------#
# Modelar la varianza ----
# -----------------------------------------------------------------------------#

# graficar los residuales absolutos y al cuadrado
base_residuales <- cbind("residuales"=mod7$residuals
                         ,"resid_sqrt"=mod7$residuals^2
                         ,"resid_abs"=abs(mod7$residuals))

## Elementos graficos residuales ----
ts_plot(base_residuales
        ,title = "Residuales Modelo 7"
        ,type = "multiple")

windows()
tsdisplay(base_residuales[,1]
          , main = "residuales") # residuales sin transformar

windows()
tsdisplay(base_residuales[,2]
          , main = "Resisuales al cuadrado") # residuales al cuadrado

windows()
tsdisplay(base_residuales[,3]
          , main = "residuales absolutos") # residuales absolutos


## Efectos ARCH ----
ArchTest(base_residuales[,1], lags = 12)
ArchTest(base_residuales[,2], lags = 12)
ArchTest(base_residuales[,3], lags = 12)

McLeod.Li.test(y=base_residuales[,1])


## identificacion GARCH ----

# sobre los residuales al cuadrado

eacf(base_residuales[,2]) # estructura ARMA(1,1),  ARMA(3,4)  o ARMA(4,4)
                          # entonces:  GARCH(1,1), GARCH(4,3) o GARCH(4,4)
                          # Se invierte, aunque es mas por experimentacion


# sobre los residuales en valor absoluto

eacf(base_residuales[,3]) # estructura ARMA(1,3) o  ARMA(3,4),  ARMA(2,6)
                          # entonces:  GARCH(3,1) o GARCH(4,3), GARCH(6,2) 

# Mensaje:
# 1. El modelo ARCH(q) es GARCH(q,0) no hay componenete de volitidad rezagada en la regresion
# 2. procesos GARCH mas grandes implican problemas de convergencia para la estimacion
# 3. Si no son series muy problematicas un modelo GARCH(1,1) es suficiente
# 4. para eacf se identifica el proceso ARMA(p,q) -> GARCH(q,p)



## Especificacion estructuras GARCH ----

# Asumiendo que media condicional es cero 
# proceso ARCH(1) sobre los retornos log

## modelo ARCH(1) ----
spec0 <- ugarchspec(mean.model = list(armaOrder= c(0,0))
                    ,variance.model = list(model='sGARCH'
                                           , garchOrder= c(1,0)
                                           )
                    , distribution.model='norm')

mod1a <- ugarchfit(spec = spec0,data = Base_modelo_dep_ts_dlx[,1])
mod1a


## modelo GARCH(1,1) ----
### serie en retornos log ----

# asumiendo que media condicional es cero

spec1 <- ugarchspec(mean.model = list(armaOrder= c(0,0))
                    ,variance.model = list(model='sGARCH'
                                           , garchOrder= c(1,1))
                    , distribution.model='norm')

mod1b <- ugarchfit(spec = spec1,data = Base_modelo_dep_ts_dlx[,1])
mod1b


# Cambiando distribucion de la volatilidad (sigma)
spec3 <- ugarchspec(mean.model = list(armaOrder= c(0,0))
                    ,variance.model = list(model='sGARCH'
                                           , garchOrder= c(1,1)
                                           )
                    , distribution.model='std')

mod1c <- ugarchfit(spec = spec3,data = Base_modelo_dep_ts_dlx[,1])
mod1c


## modelo ARMA(1,2) + eGARCH(1,1) ----
### serie en retornos log ----

spec4 <- ugarchspec(mean.model = list(armaOrder= c(1,2))
                    ,variance.model = list(model='eGARCH'
                                           , garchOrder= c(2,3)
                    )
                    , distribution.model='std')

mod2a <- ugarchfit(spec = spec4,data = Base_modelo_dep_ts_dlx[,1])
mod2a

windows()
plot(mod2a, which='all')


## modelo ARMA(2,2) + gjrGARCH(3,3) ----
### serie en retornos log con exogenas ----

spec5 <- ugarchspec(mean.model = list(armaOrder= c(2,2)
                                      , external.regressors = Base_modelo_dep_ts_dlx[,-1] 
                                      , archm = T)
                    ,variance.model = list(model='sGARCH'
                                           , garchOrder= c(3,3)
                    )
                    , distribution.model='sged')

mod3a <- ugarchfit(spec = spec5,data = Base_modelo_dep_ts_dlx[,1])
mod3a

windows()
plot(mod3a)



## modelo ARMA-GARCH con exogenas para la media
## modelo ARMA(0,1) + GARCH(4,3) con diferencia d=1 ----
### serie en niveles log con exogenas ----

spec6 <- ugarchspec(variance.model = list(model = "sGARCH", garchOrder = c(4, 3), 
                                         submodel = NULL, external.regressors = NULL
                                         , variance.targeting = FALSE), 
                   mean.model = list(armaOrder = c(0, 1)
                                     , external.regressors = Base_modelo_dep_ts_log[,c(-1,-5)]
                                     , arfima = T
                                     )
                   ,fixed.pars = list(arfima = 1)
                   ,distribution.model = "sstd")

mod7a <- ugarchfit(spec=spec6,data=Base_modelo_dep_ts_log[,5]
                      ,solver.control=list(tol = 1e-12 ))
mod7a

# Si se presentan problemas de convergencia en la estimacion se puede cambiar
# la forma en que el algoritmo puede obtener la convergencia de los estimadores

mod7b <- ugarchfit(spec=spec6,data=Base_modelo_dep_ts_log[,5]
                   ,solver = "hybrid")
mod7b



# Refinamientos  ----
## modelo ARMA(0,1) + eGARCH(6,2) con diferencia d=1 ----
### serie en niveles log con exogenas ----

spec7 <- ugarchspec(variance.model = list(model = "csGARCH", garchOrder = c(4, 3), 
                                          submodel = NULL, external.regressors = NULL
                                          , variance.targeting = FALSE
                                          ), 
                    mean.model = list(armaOrder = c(6, 3)
                                      , external.regressors = Base_modelo_dep_ts_log[,c(-1,-5)]
                                      , archm = T
                                      , arfima = T
                                      )
                    , fixed.pars = list(arfima = 1) 
                    , distribution.model = "std")

mod7c <- ugarchfit(spec=spec7,data=Base_modelo_dep_ts_log[,5]
                   ,solver = "hybrid")
mod7c

windows()
plot(mod7c,which='all')

# /------------------------------------------------------------------------  ---- 


# Pronostico de modelos GARCH estimados ----

## Modelo en retornos log 'mod1b' ----
mod1b

fore_mod1b <- ugarchforecast(fitORspec = mod1b
                             , external.forecasts = list(mregfor = NULL
                                                         , vregfor = NULL))
fitted(fore_mod1b)  # pronostico Retorno
sigma(fore_mod1b)   # pronostico volatilidad (sigma)

windows()
plot(fore_mod1b,which=1)



## Modelo en retornos log 'mod3a' ----

diff(log(Base_exo_pronos_ts))

fore_mod3a <- ugarchforecast(fitORspec = mod3a, n.ahead = nrow(diff(log(Base_exo_pronos_ts)))
                                              , out.sample = 15, n.roll = 0
                                              , external.forecasts = list(mregfor = diff(log(Base_exo_pronos_ts))
                                              , vregfor = NULL))
fore_mod3a

windows()
plot(fore_mod3a,which=1)


## Modelo en niveles log 'mod7b' ----
mod7b

fore_mod7b <- ugarchforecast(fitORspec = mod7b, n.ahead = nrow(log(Base_exo_pronos_ts))
                             , out.sample = 15, n.roll = 0
                             , external.forecasts = list(mregfor = log(Base_exo_pronos_ts)
                                                         , vregfor = NULL))
fore_mod7b

windows()
plot(fore_mod7b,which=1)


## Modelo en niveles log 'mod7c' ----

fore_mod7c <- ugarchforecast(fitORspec = mod7c, n.ahead = nrow(log(Base_exo_pronos_ts))
                             , out.sample = 0, n.roll = 0
                             , external.forecasts = list(mregfor = log(Base_exo_pronos_ts)
                                                         , vregfor = list(beta3=0.170378)))
fore_mod7c

fitted(fore_mod7c)  # pronostico del nivel


windows()
plot(fore_mod7c,which=1)

# obtener los niveles del indicador de la serie original
exp(fitted(fore_mod7c))


# /------------------------------------------------------------------------  ---- 
# Final de programa ----
# /------------------------------------------------------------------------  ---- 



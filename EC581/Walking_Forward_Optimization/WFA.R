################################
###   BASE STRATEGY
################################

#Load libraries
library(quantstrat)


if (!exists('.blotter')) .blotter <- new.env()
if (!exists('.strategy')) .strategy <- new.env() 
ls(all=T) #.blotter and .strategy environments added
class(.blotter)

# Define instruments
currency("USD")
stock("BIST",currency="USD",multiplier=1)

# Get data
setwd("D:/GoogleDrive/ACADEMIC/LECTURES/BOUN_2017_2/Lecture Notes/Part_05")#Change path
Data<-read.csv(file = "XU100.csv",sep = ";")
Data<-zoo(Data[,-1],as.Date(as.character(Data[,1]),format="%Y%m%d"))
names(Data)<-c("Open","High","Low","Close","Volume")
plot(Data)

.from='2005-08-01'
.to='2016-05-25'

BIST<-xts(coredata(Data),
          as.POSIXct(time(Data)))#Must be POSIXct
BIST<-BIST[paste0(.from,"/",.to)]

# Define strategy component names
strategy.st = 'GoldenCross'
portfolio.st = 'TrendFollowing'
account.st = 'AkInvestment'

# If you removed all objects from the global environment,
# then you may need to recreate .blotter and .strategy environments
#.blotter<-new.env()
#.strategy<-new.env()

# If you previously run the same strategy: 
# You should first remove old strategy/order book/account/portfolio objects 
rm.strat(strategy.st)
rm.strat(portfolio.st)
rm.strat(account.st)
if (!exists('.blotter')) .blotter <- new.env()
if (!exists('.strategy')) .strategy <- new.env() 
 

# Initialize portfolio&account in .blotter, 
# and orderbook&strategy in .strategy environments
initDate<-as.character(as.Date(.from)-1) # One day before data starts
initEq<-30000

initPortf(portfolio.st, 
          symbols='BIST', 
          initDate=initDate, 
          currency='USD')
initAcct(account.st, 
         portfolios=portfolio.st, 
         initDate=initDate, 
         currency='USD',
         initEq=initEq)
initOrders(portfolio.st, 
           initDate=initDate)
strategy(strategy.st, 
         store=TRUE)



# See what's inside the environments
ls(envir=FinancialInstrument:::.instrument)
temp<-get("BIST",envir = FinancialInstrument:::.instrument)
temp<-get("USD",envir = FinancialInstrument:::.instrument)

ls(all=T) #.blotter and .strategy environments are inside Global Env

ls(all=T,envir=.blotter)
temp<-get("account.AkInvestment",envir = .blotter)
temp<-get("portfolio.TrendFollowing",envir = .blotter)

ls(all=T,envir=.strategy)
temp<-get("order_book.TrendFollowing",envir = .strategy)
temp<-get("GoldenCross",envir = .strategy)

class(temp) #Analyze the object class
str(temp) # And its structure 
summary(temp) # Use this especially for strategy object




# Add indicators
.fast = 10
.slow = 20

add.indicator(strategy.st, 
              name = "SMA",
              arguments = list(
                x = quote(Cl(mktdata)[,1]),
                n = .fast
              ),
              label="nFast"
)

add.indicator(strategy.st, name="SMA",
              arguments = list(
                x = quote(Cl(mktdata)[,1]),
                n = .slow
              ),
              label="nSlow"
)

summary(get("GoldenCross",envir = .strategy))

# Add signals

add.signal(strategy.st, 
           name='sigCrossover',
           arguments = list(
             columns=c("nFast","nSlow"),
             relationship="gte"
           ),
           label='long'
)

add.signal(strategy.st, name='sigCrossover',
           arguments = list(
             columns=c("nFast","nSlow"),
             relationship="lt"
           ),
           label='short'
)

summary(get("GoldenCross",envir = .strategy))

# Add rules (i.e. when to send orders)
.orderqty = 1
.threshold = 0.005
.txnfees = 0		# round-trip fee

add.rule(strategy.st, 
         name='ruleSignal',
         arguments=list(sigcol='long' , 
                        sigval=TRUE,
                        orderside='long' ,
                        ordertype='stoplimit', 
                        prefer='High', 
                        threshold=.threshold,
                        tmult=TRUE,
                        orderqty=+.orderqty,
                        replace=FALSE
         ),
         type='enter',
         label='EnterLONG'
)

add.rule(strategy.st, name='ruleSignal',
         arguments=list(sigcol='short', 
                        sigval=TRUE,
                        orderside='long' ,
                        ordertype='market',
                        orderqty='all',
                        TxnFees=.txnfees, #Only on exits
                        replace=TRUE #Replace any pending open orders
         ),
         type='exit',
         label='Exit2SHORT'
)


add.rule(strategy.st, name='ruleSignal',
         arguments=list(sigcol='short', 
                        sigval=TRUE,
                        orderside='short',
                        ordertype='stoplimit', 
                        prefer='Low', 
                        threshold=-.threshold,
                        tmult=TRUE,
                        orderqty=-.orderqty,
                        replace=FALSE
         ),
         type='enter',
         label='EnterSHORT'
)

add.rule(strategy.st, name='ruleSignal',
         arguments=list(sigcol='long' , 
                        sigval=TRUE,
                        orderside='short',
                        ordertype='market',
                        orderqty='all',
                        TxnFees=.txnfees,#Only on exits
                        replace=TRUE #Replace any pending open orders
         ),
         type='exit',
         label='Exit2LONG'
)


summary(get("GoldenCross",envir = .strategy))


# Apply strategy
applyStrategy(strategy.st, portfolio.st)

# Update portfolio & account
updatePortf(portfolio.st)
updateAcct(account.st)
updateEndEq(account.st)

# Analyze performance
chart.Posn(portfolio.st, "BIST")

################################
###   IN-SAMPLE OPTIMIZATION
################################


# Define parameter space 
.FastSMA = c(1,3,5,10,15,20,50)
.SlowSMA = c(10,20,50,100,150,200)

.FastSMA = c(1,3,5,10)
.SlowSMA = c(10,20,50)

add.distribution(strategy.st,
                 paramset.label = 'SMA',
                 component.type = 'indicator',
                 component.label = 'nFast',
                 variable = list(n = .FastSMA),
                 label = 'nFAST'
)

add.distribution(strategy.st,
                 paramset.label = 'SMA',
                 component.type = 'indicator',
                 component.label = 'nSlow',
                 variable = list(n = .SlowSMA),
                 label = 'nSLOW'
)

add.distribution.constraint(strategy.st,
                            paramset.label = 'SMA',
                            distribution.label.1 = 'nFAST',
                            distribution.label.2 = 'nSLOW',
                            operator = '<',
                            label = 'SMA'
)

summary(get("GoldenCross",envir = .strategy))

# Apply parameter optimization
library(doParallel)
detectCores()
registerDoParallel(cores=8) # Parallel computing

# Use nsamples if you want random samples from the parameter space
results <- apply.paramset(strategy.st, 
                          paramset.label='SMA', 
                          portfolio.st=portfolio.st, 
                          account.st=account.st, 
                          verbose=TRUE)
stopImplicitCluster()

# Analyze results
class(results) # A long list object containing results
names(results) # "tradeStats" contains summaries

stats <- results$tradeStats
View(stats)
names(stats)

# Function for plotting
require(akima)
require(plot3D)

Heat.Map<-function(x,y,z,title){
  s=interp(x,y,z)
  image2D(s,main=title)
}


# Plot results
par(mfrow=c(3,2),mar=c(2,2,2,2)) # 3x2 plots on same page
Heat.Map(stats[,"nFAST"],stats[,"nSLOW"],stats[,"Net.Trading.PL"],"Net.Trading.PL")
Heat.Map(stats[,"nFAST"],stats[,"nSLOW"],stats[,"Percent.Positive"],"Percent.Positive")
Heat.Map(stats[,"nFAST"],stats[,"nSLOW"],stats[,"Profit.Factor"],"Profit.Factor")
Heat.Map(stats[,"nFAST"],stats[,"nSLOW"],stats[,"Ann.Sharpe"],"Ann.Sharpe")
Heat.Map(stats[,"nFAST"],stats[,"nSLOW"],stats[,"Max.Drawdown"],"Max.Drawdown")
Heat.Map(stats[,"nFAST"],stats[,"nSLOW"],stats[,"Profit.To.Max.Draw"],"Profit.To.Max.Draw")
par(mfrow=c(1,1),mar=c(5.1, 4.1, 4.1, 2.1))

################################
###   WALK FORWARD ANALYSIS
################################

# Perform WFA
# Optimize over last 36 months
# Trade with optimized params during next 12 months
# Only search for 10 param combos
# Select the param combo with the highest profit/max drawdown
# Rolling WFA, not anchored

WFA<-walk.forward(
  strategy.st=strategy.st, 
  portfolio.st=portfolio.st, 
  account.st=account.st,
  paramset.label='SMA', # Use this paramset
  period='months', 
  k.training=36, # Optimize over last 36 months
  k.testing=12, # Trade with optimized params during next 12 months
  nsamples=10, # Only search for 10 param combos
  obj.func=function(x){which(x == max(x,na.rm=T))},#Obj fnc 
  obj.args=list(x=quote(tradeStats.list$Profit.To.Max.Draw)), #Obj fnc args
  audit.prefix='wfa', # Will be used in creating RData filenames
  anchored=FALSE) # Rolling WFA, not anchored

# Check the files generated in WFA
# getwd() --> location of files
fls<-list.files(pattern="^wfa.*\\.RData$")

audit.file<-fls[1]
load(audit.file)
ls(all=TRUE) # note ".audit" envir
ls(.audit)

load("wfa.results.RData")
ls(.audit)

# Analyze training set results
chart.forward.training(fls[1])
chart.forward.training(fls[2])
chart.forward.training(fls[3])

# Analyze training set results
chart.forward("wfa.results.RData")

import SwiftUI


/**
  * Quote data of Equity security
 */
struct QuoteEquity
{
    //52WeekHigh    number($double)
    //example: 145.09
    //Higest price traded in the past 12 months, or 52 weeks
    var FiftyTwoWeekHigh: Double
    
    //52WeekLow    number($double)
    //example: 77.581
    //Lowest price traded in the past 12 months, or 52 weeks
    var FiftyTwoWeekLow: Double

    //askMICId    string
    //example: XNYS
    //ask MIC code
    var AskMICId: String

    //askPrice    number($double)
    //example: 124.63
    //Current Best Ask Price
    var AskPrice: Double

    //askSize    integer($int32)
    //example: 700
    //Number of shares for ask
    var AskSize: Int32

    //askTime    integer($int64)
    //example: 1621376892336
    //Last ask time in milliseconds since Epoch
    var askTime: Int64

    //bidMICId    string
    //example: XNYS
    //bid MIC code
    var BidMICId: String

    //bidPrice    number($double)
    //example: 124.6
    //Current Best Bid Price
    var bidPrice: Double

    //bidSize    integer($int32)
    //example: 300
    //Number of shares for bid
    var bidSize: Int32

    //bidTime    integer($int64)
    //example: 1621376892336
    //Last bid time in milliseconds since Epoch
    var bidTime: Int64

    //closePrice    number($double)
    //example: 126.27
    //Previous day's closing price
    var closePrice: Double

    //highPrice    number($double)
    //example: 126.99
    //Day's high trade price
    var highPrice: Double

    //lastMICId    string
    //example: XNYS
    //Last MIC Code
    var lastMICId: String

    //lastPrice    number($double)
    //example: 122.3
    var lastPrice: Double

    //lastSize    integer($int32)
    //example: 100
    //Number of shares traded with last trade
    var lastSize: Int32

    //lowPrice    number($double)
    //Day's low trade price
    var lowPrice: Double

    //mark    number($double)
    //example: 52.93
    //Mark price
    var mark: Double

    //markChange    number($double)
    //example: -0.01
    //Mark Price change
    var markChange: Double

    //markPercentChange    number($double)
    //example: -0.0189
    //Mark Price percent change
    var markPercentChange: Double

    //netChange    number($double)
    //example: -0.04
    //Current Last-Prev Close
    var netChange: Double

    //netPercentChange    number($double)
    //example: -0.0756
    //Net Percentage Change
    var netPercentChange: Double

    //openPrice    number($double)
    //example: 52.8
    //Price at market open
    var openPrice: Double

    //quoteTime    integer($int64)
    //example: 1621376892336
    //Last quote time in milliseconds since Epoch
    var quoteTime: Int64

    //securityStatus    string
    //example: Normal
    //Status of security
    var securityStatus: String

    //totalVolume    integer($int64)
    //example: 20171188
    //Aggregated shares traded throughout the day, including pre/post market hours.
    var totalVolume: Int64

    //tradeTime    integer($int64)
    //example: 1621376731304
    //Last trade time in milliseconds since Epoch
    var tradeTime: Int64

    //volatility    number($double)
    //example: 0.0094
    //Option Risk/Volatility Measurement
    var volatility: Double
}



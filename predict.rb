require './lib/hmm'
require 'mongo_mapper'
require 'csv'
require 'open-uri'
require 'rubystats'
require 'net/http'

class Quote
include MongoMapper::Document

    key :date, Date
    key :o, Float
    key :c, Float
    key :d, Float
    key :t, String
end

class Prediction
include MongoMapper::Document

    key :date, Date
    key :ticker, String
    key :o, Float
    key :c, Float
    key :delta, Float
    key :likelihood, Float
    key :pv, Float
end

MongoMapper.connection = Mongo::Connection.new('localhost', 27017)
MongoMapper.database = "hmm"
Models = {}

def init(file="companylist.csv")

    #puts "clearing collections"
    Prediction.delete_all

    #puts "opening master file #{file}"
    CSV.new(open(file)).each do |row|

        Quote.delete_all
        for i in -100..100 do
            Models[i] = HMM::Classifier.new
        end

        ticker = row[0]
        next if ticker == 'Symbol'
        #puts "fetching #{ticker}" 
        url = "http://ichart.finance.yahoo.com/table.csv?d=6&e=1&f=2015&g=d&a=7&b=19&c=2004%20&ignore=.csv&s=#{ticker}"
        count = 0
        begin
            CSV.new(open(url)).each do |line|
                q = Quote.new
                q.date = line[0]
                q.o = line[1]
                q.c = line[4]
                q.t = ticker
                q.save
                count = count + 1
                break if count == 1000
            end
        rescue
        end
        puts "#{count} records for #{ticker}"
        next if count == 0# or count < 1000 or count > 2000

        puts "train #{ticker}"
        train(ticker)
        
        puts "predict #{ticker}"
        predict(ticker)
    end

    #puts "report"
    report
end


def train(ticker)

    #puts "records for #{ticker} == #{Quote.where(:t => ticker).count}"
    startdate = 730.days.ago
    #for i in (1..Quote.where(:t => ticker, :date.gt => startdate).count - 5).step(1) do
    begin
    for i in (1..500).step(1) do
        quotes = Quote.where(:t => ticker, :date.gt => startdate).sort(:date.asc).limit(5).skip(i).to_a.reverse!

        t = (1 - (quotes.first.o/quotes.last.c))*100
       
        next if t >= 100 or t <= -100
        outputs = []
        for q in quotes do
                puts "#{q.t} -> #{q.date} -> #{q.c}"
            d = (1 - (q.o/q.c))*100
            outputs << d.to_i
        end
        model =  Models[t.to_i]
        model.add_to_train(outputs, ['A', 'B', 'C', 'D', 'E']) 
    end
    rescue
    end

    for delta, model in Models do
        if model.o_lex.empty?
            Models.delete(delta)
        else
            model.train
        end
    end
end

def predict(ticker)
    start = Time.now 
    return if Quote.where(:t => ticker).count < 100
    quotes = Quote.where(:t => ticker, :date.lte => start).limit(4).to_a.reverse!

    outputs = []
    for q in quotes[0..3] do
        puts "train #{q.t} -> #{q.date} -> #{q.c}"
        d = ((1 - (q.o/q.c))*100)
        outputs << d.to_i
    end

    lh = {}
    for delta, model in Models do
        tmp = Array.new(outputs)
        final = quotes[0].o + (quotes[0].o / 100) * delta
        difference = final - quotes[3].c
        percent = difference / quotes[3].c
        percent += 1
        final_number = quotes[3].c * percent
        d = ((1 - (quotes[3].c/final_number))*100)
        tmp << d.to_i
        begin
            lh[model.log_likelihood(tmp)] = delta
        rescue Exception => e  
        end
    end

    k = lh.keys.max
    v = lh[k]
    puts "#{quotes[0].c} --> #{quotes[0].o * (1 + (v.to_f/100))}"  
    begin
        pdf = Rubystats::NormalDistribution.new()
        p = Prediction.new({:delta => v, 
                            :ticker => ticker, 
                            :o => quotes[3].c, 
                            :c => quotes[0].o * (1 + (v.to_f/100)), 
                            :likelihood => k, 
                            :date => quotes[3].date,
                            :pv => (pdf.pdf(k) * v).abs})
        p.save
    rescue
        puts "Failed to save #{ticker}"
    end
end

def report
    hll = Prediction.first(:order => :likelihood.desc)
    hl = Prediction.first(:order => :delta.desc)
    hs = Prediction.first(:order => :delta.asc)
    hlpv = Prediction.first(:order => :pv.desc, :delta.gt => 0)
    hlpvd3 = Prediction.first(:order => :pv.desc, :delta.gte => 3, :delta.lt => 5)
    hlpvd5 = Prediction.first(:order => :pv.desc, :delta.gte => 5, :delta.lt => 10)
    hlpvd10 = Prediction.first(:order => :pv.desc, :delta.gte => 10)
    hspv = Prediction.first(:order => :pv.desc, :delta.lt => 0)

    for r in [[hll, "hll"], 
              [hl, "hl"],
              [hs, "hs"],
              [hlpv, "hlpv"],
              [hlpvd3, "hlpvd3"],
              [hlpvd5, "hlpvd5"],
              [hlpvd10, "hlpvd10"],
              [hspv, "hspv"]] do
        begin
            post(r[0], r[1])
        rescue
        end
    end
end

def post(r, destination)
    @host = "towerofglass.herokuapp.com"
    @port = 80
    @post_ws = "/widgets/#{destination}"
    @payload = {'auth_token' => 'hoopla', 
                'current' => r.c.round(2),
                'title' => r.ticker,
                'difference' => r.delta
    }.to_json
    
    req = Net::HTTP::Post.new(@post_ws, initheader = {'Content-Type' =>'application/json'})
    req.body = @payload
    response = Net::HTTP.new(@host, @port).start {|http| http.request(req) }
    puts "Response #{response.code} #{response.message}:#{response.body}"
end

if ARGV[0] == 'predict'
    init(ARGV[1])
    report
elsif ARGV[0] == 'report'
    report
else
    puts "usage: ruby predict.rb [predict <dji.csv|sp500.csv|nasdaq.csv> | report]"
end

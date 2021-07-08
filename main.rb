require "sinatra"
require "sinatra/reloader"

set :environment, :production

def calc(y, m, d)
    return (y + (y/4) - (y/100) + (y/400) + ((13*m + 8) / 5) + d) % 7
end

def colorGudge(y, m, d)
    sty = if(m == 7 && d == 30)
        "#f57f17 amber-text darken-4"
    else
        "black-text"
    end
    return sty
end

def lastDay(m)
    return case m
    when 1, 3, 5, 7, 8, 10, 12
        31
    when 2, 4, 6, 9, 11
        30
    end
end

get "/" do
    t = Time.new
    @year = t.year
    @month = t.month
    erb :calender
end

get "/:year/:month" do
    @year = params[:year].to_i
    @month = params[:month].to_i

    erb :calender
end
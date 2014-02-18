class DunsServer
  include HTTParty
  base_uri "http://dnbdirect-api.dnb.com/DnBAPI-15/rest"
  headers "username" => ENV['DUNS_USERNAME']
  headers "password" => ENV['DUNS_PASSWORD']
  headers "API-KEY"  => ENV['DUNS_KEY']

  def self.company_search(term)
    response = self.get "/search/company/#{term}"

    company_name = response["resultSet"]["hit"].first["companyResults"]["companyName"] rescue nil
    company_id = response["resultSet"]["hit"].first["companyResults"]["companyId"] rescue nil

    if company_name || company_id
      company = Company.find(uid: company_id)
      company ||= Company.create(name:company_name, uid: company_id)
    end
  end

  def self.competitor_search(company)
    return nil unless company
    response = self.get("/company/#{company.uid}/competitors", 
                        query: { top_competitors: true })

    competitors = response["competitor"] rescue nil

    if competitors 
      competitors_limit = [competitors.count, 4].min

      competitors[0..competitors_limit].each do |item|
        name = item["companyName"]
        uid = item["companyId"]
        competitor = Company.find(uid: uid)
        competitor ||= Company.create(name: name,uid: uid)
        company.competitors << competitor if competitor
      end
    end
    competitors
  end

  def self.news_search(company)
    return nil unless company
    start_date = DateTime.yesterday.strftime("%Y-%m-%d")
    end_date = DateTime.now.strftime("%Y-%m-%d")
    news_filter = "GeneralIndustry"

    response = self.get("/company/#{company.uid}/news",
                        query: { start_date: start_date,
                                 end_date: end_date,
                                 filter: news_filter })

    news_articles = response["companyNews"]["newsItems"]["newsItem"] rescue nil

    if news_articles
      news_limit = [news_articles.count, 19].min
      news_articles[0..news_limit].each do |item|
        if news = News.find(link: item["link"])
          news.companies << company
        else
          news = News.new
          news.title = item["title"]
          news.text = item["text"]
          news.source = item["source"]
          news.link = item["link"]
          news.date = item["date"]
          if news.save
            news.companies << company
          end
        end
      end
    end
  end

  def self.marketcap_search(company)
    return nil unless company
    response = self.get "/company/#{company.uid}/market/data"
    marketcap = response["currentInformation"]["marketCap"] rescue nil
    company.market_cap = marketcap
  end
end

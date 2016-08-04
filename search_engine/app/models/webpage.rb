class Webpage

  require 'pg'

  attr_reader :title, :description, :url, :rank
  attr_accessor :id

  def initialize(params)
    @id = params.fetch(:id, '')
    @title = params.fetch(:title, "")
    @url = params.fetch(:url, "")
    @description = params.fetch(:description, "")
    @rank = params.fetch(:rank, "")
  end

  def self.do_search(query_string, query_from)
    return [] if query_string == ""

    begin
      connection = PG.connect :dbname => 'varys_' + ENV['RACK_ENV']
      results = connection.exec "SELECT id, title, description, url, ts_rank_cd(textsearch, query) AS rank
      FROM webpages, plainto_tsquery('english', '#{query_string}') query, to_tsvector(url || title || description) textsearch
      WHERE query @@ textsearch
      ORDER BY rank DESC"
      # LIMIT 10 OFFSET #{query_from}
    rescue PG::Error => e
      puts e.message
      results = []
    ensure
      connection.close if connection
    end

    # need to add function for checking if result is query homepage (if query string has no spaces)
    #
    # popularity table?
    #
    # loop through database again for both and adjust ranking accordingly

    result_objects = convert_results_to_objects(results)

    result_objects.each do |result|
      url_length = get_extra_nodes(result.url).length
      result.rank -= (result.rank * 0.25) * url_length
      result.rank *= 1.5 if url_length == 0
    end

    result_objects.sort_by! do |result|
      result.rank
    end

    result_objects.reverse
  end

  def self.get_extra_nodes(url)
    site_nodes = url.split(/[\/]/)
    url_parts = ["http:", "https:", ""]
    site_nodes - url_parts - [get_root(url)]
  end

  def self.get_root(url)
    site_nodes = url.split(/[\/]/)
    site_nodes[2]
  end

  def self.get_homepage(site_root)
    url_parts = ["www", "org", "uk", "gov", "com", "co"]
    site_root.split('.') - url_parts
  end

  def self.get_all_results(query_string)

    begin
      connection = PG.connect :dbname => 'varys_' + ENV['RACK_ENV']
      results = connection.exec "SELECT id, title, description, url, ts_rank_cd(textsearch, query) AS rank
      FROM webpages, plainto_tsquery('english', '#{query_string}') query, to_tsvector(url || title || description) textsearch
      WHERE query @@ textsearch
      ORDER BY rank DESC"
      # LIMIT 10 OFFSET #{query_from}
    rescue PG::Error => e
      puts e.message
      results = []
    ensure
      connection.close if connection
    end

    convert_results_to_objects(results)
  end

  def save!

    begin
      connection = PG.connect :dbname => 'varys_' + ENV['RACK_ENV']
      connection.exec "INSERT INTO webpages (title, description, url) VALUES('#{self.title}','#{self.description}','#{self.url}');"
      id = connection.exec "SELECT id FROM webpages WHERE title = '#{self.title}'"
    rescue PG::Error => e
      puts e.message
    ensure
      connection.close if connection
    end
    self.id = id.values.last[0].to_i
  end

  private

  def self.convert_results_to_objects(query_results)
    results = []
    query_results.map do |result|
      results << Webpage.new( id: result['id'],
      title: result['title'],
      url: result['url'],
      description: result['description'],
      rank: result['rank']
      )
    end
    results
  end
end

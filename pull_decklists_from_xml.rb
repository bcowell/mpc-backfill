#! /usr/bin/env ruby

# gem install nokogiri
require 'nokogiri'

input_xml_dir = './example-decks'
output_dir = './decklists' # create this if it doesnt exist

class PullDecklistFromXML
  def initialize(
    input_xml_dir, 
    output_dir
  )
    @input_xml_dir = input_xml_dir
    @output_dir = output_dir
  end

  def perform!
    Dir.each_child(@input_xml_dir) do |filename|
      deck_name = filename.split(".")[0]
      input_file_path = "#{@input_xml_dir}/#{filename}"
      output_file_path = "#{@output_dir}/#{deck_name}.txt"

      document = open_file(input_file_path)
      decklist = pull_decklist(document)
      save_output_to_file(output_file_path, decklist.join("\n"))
    end
  end

  def open_file(deck_file_path)
    deck_file = File.open(deck_file_path)
    
    document = Nokogiri::XML(deck_file)

    document
  end

  def pull_decklist(document)
    decklist = document.search('//fronts/card/name').map(&:text)
    decklist = decklist.map do |card|
      card = card.gsub('.png', '')
      card = card.gsub('.jpg', '')
      card = card.gsub('_', "'")
    end
    
    decklist
  end

  def save_output_to_file(output_file_path, output)
    File.write(output_file_path, output)
  end
end

pull_decklists = PullDecklistFromXML.new(input_xml_dir, output_dir)
pull_decklists.perform!
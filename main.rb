#! /usr/bin/env ruby

# gem install nokogiri
require 'nokogiri'

# Each deck has two card lists, one front and one back
# we want to fill the empty spots of the back with fronts from another deck
# some cards can potentially already have a back that matches a front's <slots> index
# Ex.
# front = [1, 2, ... 103]
# back =  [3, 45, 78]
def print_double_sided(deck_a_file_path, deck_b_file_path, output_file_path)
  deck_a_file = File.open(deck_a_file_path)
  deck_b_file = File.open(deck_b_file_path)
  
  doc_a = Nokogiri::XML(deck_a_file)
  doc_b = Nokogiri::XML(deck_b_file)

  back_count_a = doc_a.search('//backs/card').count
  back_count_b = doc_b.search('//backs/card').count

  # first choose the deck that has less backs (more space to fill)
  if (back_count_a < back_count_b)
    primary_doc, secondary_doc = doc_a, doc_b
  else
    primary_doc, secondary_doc = doc_b, doc_a
  end

  # max amount of cards we can include
  max_primary_bracket = primary_doc.search('//bracket').text.to_i
  max_secondary_bracket = secondary_doc.search('//bracket').text.to_i

  # ref to front and back root node
  primary_front_node = primary_doc.at('//fronts')
  primary_back_node = primary_doc.at('//backs')

  # nodelists of all primary & secondary front/back cards
  primary_front_nodelist = primary_doc.search('//fronts/card')
  primary_back_nodelist = primary_doc.search('//backs/card')
  secondary_front_nodelist = secondary_doc.search('//fronts/card')
  secondary_back_nodelist = secondary_doc.search('//backs/card')

  # array of slot ids of the already existing back cards
  # Ex. [19, 55, 59, 91]
  primary_back_slot_ids = array_of_back_slot_ids(primary_doc)
  secondary_back_slot_ids = array_of_back_slot_ids(secondary_doc)

  p "primary_back_slot_ids: #{primary_back_slot_ids}"
  p "secondary_back_slot_ids: #{secondary_back_slot_ids}"

  nodes_to_add_to_end = []

  # 1. starting from last back fill the empty back slots using front of other deck
  secondary_front_nodelist.each do |secondary_front_node|
    front_slot_id = secondary_front_node.css('slots').text.to_i

    if (primary_front_nodelist.count >= max_primary_bracket) ||
      (primary_back_nodelist.count >= max_primary_bracket)
      p 'Run out of room for cards in the primary deck'
      p "front: #{primary_front_nodelist.count}/#{max_primary_bracket}"
      p "back: #{primary_back_nodelist.count}/#{max_primary_bracket}"
      break
    end

    if (primary_back_slot_ids.include?(front_slot_id))
      # p 'the new slot_id already is taken by a primary card'
      # unshift - add to front of leftovers so we can deal with these first
      nodes_to_add_to_end.unshift(secondary_front_node)
      # print_node(secondary_front_node)

    elsif (secondary_back_slot_ids.include?(front_slot_id))
      # p 'the new front to add has a back as well'
      nodes_to_add_to_end.push(secondary_front_node)
      # print_node(secondary_front_node)

    else
      primary_back_node.add_child(secondary_front_node)
    end
  end

  nodes_to_add_to_end.each do |secondary_front_node|
    front_slot_id = secondary_front_node.css('slots').text.to_i
    
    if (primary_front_nodelist.count >= max_primary_bracket) ||
      (primary_back_nodelist.count >= max_primary_bracket)
      p 'Run out of room for cards in the primary deck'
      p "front: #{primary_front_nodelist.count}/#{max_primary_bracket}"
      p "back: #{primary_back_nodelist.count}/#{max_primary_bracket}"
      break
    end

    if (secondary_back_slot_ids.include?(front_slot_id))
      p 'the new front to add has a back as well'
      print_node(secondary_front_node)
      # we need to add both front & back
      # find first equal matching slot_id on front and back primary
      # update slot_id of both and add to both
    else
      last_back_node = primary_doc.search('//backs/card').last()
      last_back_node_slot_id = last_back_node.css('slots').text.to_i

      secondary_front_node.at('slots').replace("<slots>#{last_back_node_slot_id + 1)}</slots>")
      print_node(secondary_front_node)
      break
      # update slot id for front
      # primary_back_node.add_child(secondary_front_node)
    end
  end

  File.write(output_file_path, primary_doc)
end

def array_of_back_slot_ids(doc)
  back_slot_ids = []

  doc.search('//backs/card/slots').each do |el|
    back_slot_ids << el.text.to_i
  end

  back_slot_ids
end

def print_node(node)
  hash = {}
  node.elements.each do |el|
    hash[el.name] = el.text
  end
  p hash
end

deck_a_file_path = './example-decks/w_weenie.xml'
deck_b_file_path = './example-decks/vial_krark.xml'
output_file_path = './output/w_weenie_vial_krark.xml'
print_double_sided(deck_a_file_path, deck_b_file_path, output_file_path)
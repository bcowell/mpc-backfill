#! /usr/bin/env ruby

# gem install nokogiri
require 'nokogiri'

# Each deck has two card lists, one front and one back
# we want to fill the empty spots of the back with fronts from another deck
# some cards can potentially already have a back that matches a front's <slots> index
# Ex.
# front = [1, 2, ... 103]
# back =  [3, 45, 78]
class BackFill

  def initialize(
    deck_a_file_path, 
    deck_b_file_path, 
    output_file_path
  )
    @output_file_path = output_file_path
    @primary_doc = nil
    @secondary_doc = nil

    open_files_and_prepare_xml_documents(deck_a_file_path, deck_b_file_path)
  end

  def perform!
    merge_primary_and_secondary_decks
    save_combined_xml_output_to_file
  end

  def open_files_and_prepare_xml_documents(deck_a_file_path, deck_b_file_path)
    deck_a_file = File.open(deck_a_file_path)
    deck_b_file = File.open(deck_b_file_path)
    
    doc_a = Nokogiri::XML(deck_a_file)
    doc_b = Nokogiri::XML(deck_b_file)

    # primary deck should have fewer backs (more space to fill)
    # TODO: technically this should be the max of the slot id in either
    back_count_a = doc_a.search('//backs/card').count
    back_count_b = doc_b.search('//backs/card').count
    
    if (back_count_a < back_count_b)
      @primary_doc, @secondary_doc = doc_a, doc_b
    else
      @primary_doc, @secondary_doc = doc_b, doc_a
    end
  end


  def merge_primary_and_secondary_decks
    # max amount of cards we can include
    max_primary_bracket = @primary_doc.search('//bracket').text.to_i
    max_secondary_bracket = @secondary_doc.search('//bracket').text.to_i

    primary_back_node = @primary_doc.at('//backs')
    secondary_front_nodelist = @secondary_doc.search('//fronts/card')

    # array of slot ids of the already existing back cards
    # Ex. [19, 55, 59, 91]
    primary_back_slot_ids = array_of_back_slot_ids(@primary_doc)
    secondary_back_slot_ids = array_of_back_slot_ids(@secondary_doc)

    p "primary_back_slot_ids: #{primary_back_slot_ids}"
    p "secondary_back_slot_ids: #{secondary_back_slot_ids}"

    nodes_to_add_to_end = []

    # fill the empty back slots of primary using front of secondary
    # if there's a conflict of ids or we the card to add includes a back
    # store and we'll worry about those after
    secondary_front_nodelist.each do |secondary_front_node|
      front_slot_ids = get_slot_ids(secondary_front_node)

      # the back slot is already taken by a primary card
      if (primary_back_slot_ids & front_slot_ids).size > 0
        # unshift - add to front of leftovers so we can deal with these first
        nodes_to_add_to_end.unshift(secondary_front_node)

      # the new front to add has a back as well
      elsif (secondary_back_slot_ids & front_slot_ids).size > 0
        nodes_to_add_to_end.push(secondary_front_node)

      else
        primary_back_node.add_child(secondary_front_node)
      end
    end

    nodes_to_add_to_end.each do |secondary_front_node|
      front_slot_ids = get_slot_ids(secondary_front_node)

      # the new front has a back tied to it
      if (secondary_back_slot_ids & front_slot_ids).size > 0
        add_both_secondary_front_and_back_to_primary(secondary_front_node, front_slot_ids.first)

      # back slot id was already taken just add to end with new slot id
      else
        add_secondary_front_to_primary(secondary_front_node, front_slot_ids)
      end
    end

    # TODO: fix slot ids with array
    # otherwise this is not the right count
    count_and_set_card_quantity
  end

  def save_combined_xml_output_to_file
    File.write(@output_file_path, @primary_doc)
  end

  def count_and_set_card_quantity
    max_primary_front_slot_id = 0
    max_primary_back_slot_id = 0

    @primary_doc.search('//fronts/card').map do |front_card_node|
      max_slot_id = get_slot_ids(front_card_node).max
      if max_slot_id > max_primary_front_slot_id 
        max_primary_front_slot_id = max_slot_id
      end
    end
    @primary_doc.search('//backs/card').map do |back_card_node|
      max_slot_id = get_slot_ids(back_card_node).max
      if max_slot_id > max_primary_back_slot_id 
        max_primary_back_slot_id = max_slot_id
      end
    end

    new_quantity = [max_primary_front_slot_id, max_primary_back_slot_id].max
    @primary_doc.at('//quantity').content = new_quantity
  end

  def add_secondary_front_to_primary(secondary_front_node, front_slot_ids)
    primary_back_node = @primary_doc.at('//backs')

    front_slot_id = nil

    last_back_node = @primary_doc.search('//backs/card').last()
    last_back_node_slot_ids = get_slot_ids(last_back_node)
    new_slot_id = last_back_node_slot_ids.max + 1

    # throw an error if the new slot id is outside of max_primary_bracket

    if front_slot_ids.size == 1
      front_slot_id = front_slot_ids.first
      secondary_front_node.at('slots').content = new_slot_id
    else
      p 'card has multiple slot ids'
      print_node(secondary_front_node)
    end

    primary_back_node.add_child(secondary_front_node)
  end

  def add_both_secondary_front_and_back_to_primary(secondary_front_node, front_slot_id)
    primary_front_node = @primary_doc.at('//fronts')
    primary_back_node = @primary_doc.at('//backs')

    # we need to add both front & back
    # find first equal matching slot_id on front and back primary
    # update slot_id of both and add to both

    last_front_node = @primary_doc.search('//fronts/card').last()
    last_back_node = @primary_doc.search('//backs/card').last()

    front_node_slot_id = get_slot_id(last_front_node)
    back_node_slot_id = get_slot_id(last_back_node)

    new_slot_id = [front_node_slot_id, back_node_slot_id].max + 1

    # throw an error if the new slot id is outside of max_primary_bracket
    
    # update slot ids
    secondary_back_node_slot_id = @secondary_doc.at("//backs/card/slots[text()=#{front_slot_id}]")
    secondary_back_node_slot_id.content = new_slot_id
    secondary_front_node.at('slots').content = new_slot_id
    
    secondary_back_node = secondary_back_node_slot_id.parent

    primary_back_node.add_child(secondary_front_node)
    primary_front_node.add_child(secondary_back_node)
  end

  def get_slot_id(node)
    query = node.css('slots').text
    raise "Slot id cannot be an array" if query.include? ','
    query.to_i
  end

  def get_slot_ids(node)
    query = node.css('slots').text
    if query.include? ','
      query.split(",").map(&:to_i)
    else
      [query.to_i]
    end
  end

  def pluck_max_slot_id(slot)
    id = slot.text
    if id.include? ','
      id.split(",").map(&:to_i)
    else
      [id.to_i]
    end
  end

  def array_of_back_slot_ids(doc)
    back_slot_ids = []

    doc.search('//backs/card').each do |node|
      new_ids = get_slot_ids(node)
      back_slot_ids += new_ids
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
end

# TODO: take this input from CLI
deck_a_file_path = './example-decks/w_weenie.xml'
deck_b_file_path = './example-decks/vial_krark.xml'
output_file_path = './output/w_weenie_vial_krark.xml'

backfill = BackFill.new(deck_a_file_path, deck_b_file_path, output_file_path)
backfill.perform!
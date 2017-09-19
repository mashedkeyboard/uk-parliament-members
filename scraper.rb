#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'nokogiri'
require 'scraped'
require 'scraperwiki'

require 'pry'

def noko_for(url)
  Nokogiri::XML(open(url).read)
end

def gender_from(str)
  return if str.to_s.empty?
  return 'male' if str.downcase == 'm'
  return 'female' if str.downcase == 'f'
  raise "unknown gender: #{str}"
end

def scrape_list(url)
  noko = noko_for(url)
  noko.xpath('//Members/Member').map do |member|
    email = member.xpath('Addresses//Email').flat_map { |x| x.text.split(/[ ;]/) }.map { |e| e.tidy.gsub('mailto:','') }.uniq.compact
                  .reject { |t| t.to_s.empty? || !t.to_s.include?('@') }
                  .sort_by { |e| e.include?('parliament.uk') ? -1 : 1 }
                  .join(' ; ')

    {
      id:               member.attr('Member_Id'),
      name:             member.xpath('DisplayAs').text,
      sort_name:        member.xpath('ListAs').text,
      birth_date:       member.xpath('DateOfBirth').text.to_s.sub(/T.*/, ''),
      death_date:       member.xpath('DateOfDeath').text.to_s.sub(/T.*/, ''),
      gender:           gender_from(member.xpath('Gender').text),
      party:            member.xpath('Party').text,
      party_id:         member.xpath('Party/@Id').text,
      constituency:     member.xpath('MemberFrom').text,
      email:            email.to_s.gsub('mailto:', '').strip,
      phone:            member.xpath('Addresses/Address[@Type_Id="1"]/Phone').map(&:text).join(' ; '),
      fax:              member.xpath('Addresses/Address[@Type_Id="1"]/Fax').map(&:text).join(' ; '),
      website:          member.xpath('Addresses/Address[@Type_Id="6"]/Address1').map(&:text).join(' ; '),
      twitter:          member.xpath('Addresses/Address[Type="Twitter"]/Address1').map(&:text).join(' ; '),
      facebook:         member.xpath('Addresses/Address[Type="Facebook"]/Address1').map(&:text).join(' ; '),
      blog:             member.xpath('Addresses/Address[Type="Blog"]/Address1').map(&:text).join(' ; '),
      youtube:          member.xpath('Addresses/Address[Type="Youtube"]/Address1').map(&:text).join(' ; '),
      flickr:           member.xpath('Addresses/Address[Type="Flickr"]/Address1').map(&:text).join(' ; '),
      identifier__dods: member.attr('Dods_Id'),
      identifier__pims: member.attr('Pims_Id'),
    }
  end
end

data = scrape_list('http://data.parliament.uk/membersdataplatform/services/mnis/members/query/House=Commons%7CIsEligible=true/Addresses/')
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite([:id], data)

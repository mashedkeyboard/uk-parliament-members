#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::XML(open(url).read)
end

def gender_from(str)
  return if str.to_s.empty?
  return "male" if str.downcase == 'm'
  return "female" if str.downcase == 'f'
  raise "unknown gender: #{str}"
end

def scrape_list(url)
  noko = noko_for(url)
  noko.xpath('//Members/Member').each do |member|
    email = member.xpath('Addresses//Email').map { |x| x.text.to_s.gsub('mailto:','') }.uniq.compact.
      reject { |t| t.to_s.empty? || !t.to_s.include?('@') }.
      sort_by { |e| e.include?('parliament.uk') ? -1 : 1 }.
      join(' ; ')

    data = { 
      id: member.attr('Member_Id'),
      name: member.xpath('DisplayAs').text,
      sort_name: member.xpath('ListAs').text,
      birth_date: member.xpath('DateOfBirth').text.to_s.sub(/T.*/,''),
      death_date: member.xpath('DateOfDeath').text.to_s.sub(/T.*/,''),
      gender: gender_from(member.xpath('Gender').text),
      party: member.xpath('Party').text,
      party_id: member.xpath('Party/@Id').text,
      constituency: member.xpath('MemberFrom').text,
      email: email.to_s.gsub('mailto:','').strip,
      phone: member.xpath('Addresses/Address[@Type_Id="1"]/Phone').map { |w| w.text }.join(" ; "),
      fax: member.xpath('Addresses/Address[@Type_Id="1"]/Fax').map { |w| w.text }.join(" ; "),
      website: member.xpath('Addresses/Address[@Type_Id="6"]/Address1').map { |w| w.text }.join(" ; "),
      twitter: member.xpath('Addresses/Address[Type="Twitter"]/Address1').map { |w| w.text }.join(" ; "),
      facebook: member.xpath('Addresses/Address[Type="Facebook"]/Address1').map { |w| w.text }.join(" ; "),
      blog: member.xpath('Addresses/Address[Type="Blog"]/Address1').map { |w| w.text }.join(" ; "),
      youtube: member.xpath('Addresses/Address[Type="Youtube"]/Address1').map { |w| w.text }.join(" ; "),
      flickr: member.xpath('Addresses/Address[Type="Flickr"]/Address1').map { |w| w.text }.join(" ; "),
      identifier__dods: member.attr('Dods_Id'),
      identifier__pims: member.attr('Pims_Id'),
    }
    ScraperWiki.save_sqlite([:id], data)
  end
end

scrape_list('http://data.parliament.uk/membersdataplatform/services/mnis/members/query/House=Commons%7CIsEligible=true/Addresses/')

require "omnicontacts/middleware/oauth2"
require "rexml/document"

module OmniContacts
  module Importer
    class Gmail < Middleware::OAuth2

      attr_reader :auth_host, :authorize_path, :auth_token_path, :scope

      def initialize *args
        super *args
        @auth_host = "accounts.google.com"
        @authorize_path = "/o/oauth2/auth"
        @auth_token_path = "/o/oauth2/token"
        @scope = "https://www.google.com/m8/feeds"
        @contacts_host = "www.google.com"
        @contacts_path = "/m8/feeds/contacts/default/full"
        @max_results =  (args[3] && args[3][:max_results]) || 2000
      end

      def fetch_contacts_using_access_token access_token, token_type
        contacts_response = https_get(@contacts_host, @contacts_path, contacts_req_params, contacts_req_headers(access_token, token_type))
        #group_test = "/m8/feeds/groups/Test%40livewat.ch/full"
        @@access_token = access_token
        @@token_type = token_type
        #puts https_get(@contacts_host, group_test, {}, contacts_req_headers(access_token, token_type))
        parse_contacts contacts_response
      end

      private
      def self.access_token
        @@access_token
      end

      def self.token_type
        @@token_type
      end

      def contacts_req_params
        {"max-results" => @max_results.to_s}
      end

      def contacts_req_headers token, token_type
        {"GData-Version" => "3.0", "Authorization" => "#{token_type} #{token}"}
      end

      def parse_contacts contacts_as_xml
        xml = REXML::Document.new(contacts_as_xml)
        #puts xml
        contacts = []
        xml.elements.each('//entry') do |entry|
          contact = {}
          name = entry.elements['gd:name']
          contact[:name] = name.elements['gd:fullName'].text if name
          contact[:unique_id] = entry.elements['id'].text.to_s.sub(/.*contacts\/(.*)/, '\1')

          contact[:emails] = []
          REXML::XPath.each(entry, "gd:email") do |email|
            contact_email = {}
            contact_email[:address] = email.attributes['address'].to_s
            contact_email[:label] = email.attributes['rel'].to_s.sub(/.*#(.*)/, '\1')
            contact[:emails] << contact_email
          end

          contact[:phones] = []
          REXML::XPath.each(entry, "gd:phoneNumber") do |phone|
            contact_phone = {}
            contact_phone[:number] = phone.text
            contact_phone[:label] = phone.attributes['rel'].to_s.sub(/.*#(.*)/, '\1')
            contact[:phones] << contact_phone
          end

          contact[:groups] = []
          REXML::XPath.each(entry, "gContact:groupMembershipInfo") do |group|
            contact_group = {}
            contact_group[:unique_id] = group.attributes['href'].to_s.sub(/.*groups\/(.*)/, '\1')
            contact[:groups] << contact_group
          end

          contacts << contact
        end
        puts fetch_groups
        {:contacts => contacts, :groups => fetch_groups}

      end #parse_contacts

      def fetch_groups
        groups_path = "/m8/feeds/groups/default/full"
        groups_as_xml = https_get(@contacts_host, groups_path, {}, contacts_req_headers(@@access_token, @@token_type))

        groups = []
        xml = REXML::Document.new(groups_as_xml)
        xml.elements.each('//entry') do |entry|
          group = {}
          group[:unique_id] = entry.elements['id'].text.to_s.sub(/.*groups\/(.*)/, '\1')
          group[:name] = entry.elements['title'].text.to_s

          groups << group
        end
        groups
      end #fetch_groups
    end
  end
end

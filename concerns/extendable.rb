module Extendable
  extend ActiveSupport::Concern

  included do

  end

  module ClassMethods

    def store_json store_field, accessors: {}, prefix: false
      fix_text ||= "#{prefix}_" if prefix

      class_eval do
        define_method "callback_validate_#{store_field}" do
          stroes = ActiveSupport::HashWithIndifferentAccess.new(self.send(store_field))

          accessors.each do |_attr, _attr_class|
            next if stroes[_attr].blank?

            case _attr_class.to_s
            when "String"
              stroes[_attr] = stroes[_attr].to_s
            when "TrueClass"
              stroes[_attr] = (
                stroes[_attr].eql?('t')    ||
                stroes[_attr].eql?('true') ||
                stroes[_attr].eql?(true)
              ) ? 't' : 'f'
            when "Integer"
              stroes[_attr] = stroes[_attr].to_i
            when "Float"
              stroes[_attr] = stroes[_attr].to_f
            else
            end
          end

          stroes.delete_if {|key, value| !value.is_bool? && value.blank? }

          self.send("#{store_field}=", stroes)
        end
      end

      accessors.each do |_attr, _attr_class|
        class_eval do

          define_method "#{fix_text}#{_attr}" do
            if self.send(store_field).present?
              stroes = ActiveSupport::HashWithIndifferentAccess.new(self.send(store_field))

              return stroes[_attr].eql?('t') if _attr_class.eql?(TrueClass)
              stroes[_attr]
            end
          end

          alias_method "#{fix_text}#{_attr}?", "#{fix_text}#{_attr}" if _attr_class.eql?(TrueClass)

          define_method "#{fix_text}#{_attr}=" do |value|
            stroes = self.send(store_field)
            stroes ||= ActiveSupport::HashWithIndifferentAccess.new({})
            stroes[_attr] = value

            stroes.delete_if {|key, value| !value.is_bool? && value.blank? }

            self.send("#{store_field}=", stroes)
          end
        end

        private :"callback_validate_#{store_field}"

        before_save :"callback_validate_#{store_field}"

        singleton_class.send(:define_method, "#{store_field.to_s.pluralize}_i18n") {
          table = self.table_name

          I18n.t("#{table.singularize}.#{store_field}").deep_symbolize_keys rescue {}
        }

        table = self.table_name
        proc {
          self.scope "with_#{fix_text}#{_attr}", ->(val) { where("#{table}.#{store_field} ->> '#{_attr}' = ? ", val) }
        }.call if _attr_class.eql?(String)

        proc {
          self.scope "with_#{fix_text}#{_attr}", -> { where("#{table}.#{store_field} ->> '#{_attr}' = ? ", 't') }
          self.scope "with_#{fix_text}not_#{_attr}", -> {
            where(
              "#{table}.#{store_field} ->> '#{_attr}' != ? OR
               #{table}.#{store_field} ->> '#{_attr}' IS NULL", 'f'
            )
          }
        }.call if _attr_class.eql?(TrueClass)

        proc {
          self.scope "with#{fix_text}#{_attr}", ->(val) { where("(#{table}.#{store_field} ->> '#{_attr}')::INT = ? ", val) }
        }.call if _attr_class.eql?(Integer)
      end
    end
  end
end
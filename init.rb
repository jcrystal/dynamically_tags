
require 'dynamically_tags'

ActiveRecord::Base.send(:include, DynamicallyTags::ActiveRecordExtensions)

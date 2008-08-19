module DynamicallyTags

  module ActiveRecordExtensions  

    def self.included(base)
      base.send(:extend, ClassMethods)
    end
  
    
    module ClassMethods
	
      def dynamically_tags(*attr_names)				
				attr_names[0].each do |attr_name|
					attr_names[1][:scope] ||= :all
		      create_dynamic_store_method(attr_name,attr_names[1][:scope],attr_names[1][:includes]) do |org_method, args, block|
		        org_method.call(*args, &block)
		      end

					create_recall_method(attr_name,attr_names[1][:scope]) do |org_method, args, block|
						org_method.call(*args, &block)
					end

		    end
		
				define_method 'dynamic_identify' do |str|
						out = Hash.new
				    first_number = str.index(%r{0|1|2|3|4|5|6|7|8|9})
				    out['class'] = str[0..first_number-1]
				    out['id'] = str[first_number..str.size-1]
				    out
				end
				
				define_method 'get_tagged_objects' do |*args|
					class_name = *args[0].to_s rescue nil
			    out = Array.new
					work = ""
					
					attr_names[0].each { |attr_name| work << eval('self.'+attr_name.to_s+'(true)') rescue "" }
			    #work = String.new(self.body(true))
			    while str_start = work.index('{{')
			      str_end = work.index('}}', str_start)
			      data_chunk = work[str_start+2..str_end-1]      
			      obj = dynamic_identify(data_chunk)
			      if (class_name)
			        out << eval(obj['class']+'.find_by_id('+obj['id']+')') if (obj['class'] == class_name)
			      else
			        out << eval(obj['class']+'.find_by_id('+obj['id']+')')
			      end

			      work[str_start..str_end+1] = "REMOVED"
			    end

			    return out.uniq # Removes duplicates
				end

		  end

			def create_dynamic_store_method(attr_name,scope,includes)
		    define_method attr_name.to_s+"=" do |input|
					words = input.split(%r{\b}) rescue []
					new_body = ""

					index = 0
		      while index < words.size
		        word = words[index]
		
						includes.each { |class_plural, fields|
							begin
								dynamic_text_scope = scope == :all ? eval(class_plural.to_s.singularize.capitalize) : eval('self.'+scope.to_s+'.'+class_plural.to_s)
								fields.each { |field|
									if field.class == Symbol
										match = dynamic_text_scope.find(:all, :conditions => [field.to_s+' = ?', word]) rescue []
										if match.size > 0
											word = '{{'+class_plural.to_s.singularize.capitalize+match[0].id.to_s+'}}'
										end
									elsif field.class == String
										attributes = field.split(' ') # ex ['firstname','lastname']
										attr_index = 0
										matches = []
										while (attr_index < attributes.size && (attr_index == 0 || matches.size > 0))
											if attr_index == 0
												matches = dynamic_text_scope.find(:all, :conditions => [attributes[attr_index]+' = ?',word]) rescue []
											else
												matches = matches.find_all{|item| eval('item.'+attributes[attr_index]) == words[index+2*attr_index]} rescue []
											end
											attr_index += 1
										end
									
										if matches.size > 0
											word = '{{'+class_plural.to_s.singularize.capitalize+matches[0].id.to_s+'}}'
											index += (attr_index-1)*2
										end
									end
								}
							rescue
								# do nothing.  Do not modify.
							end
						}						
						new_body += word
						index += 1
					
					end
					
					super(new_body)
		    end
		  end

			def create_recall_method(attr_name, scope)
		    define_method attr_name.to_s do |*args|
					input = super
					dynamic = args[0] rescue false
					if dynamic || input == nil
						input
					else
						out = String.new(input)
						while str_start = out.index('{{')
			        str_end = out.index('}}', str_start)
			        data_chunk = out[str_start+2..str_end-1]      
			        obj_info = dynamic_identify(data_chunk)
							begin
								dynamic_text_scope = scope == :all ? eval(obj_info['class']) : eval('self.'+scope.to_s+'.'+obj_info['class'].downcase.pluralize)
								obj = dynamic_text_scope.find(obj_info['id'])
				        out[str_start..str_end+1] = obj.name if obj
							rescue
								out[str_start..str_end+1] = obj_info['class'] # If error, just put "Contact", or whatever
							end
			      end
						out
					end
		    end
		  end
    end  
  end
end

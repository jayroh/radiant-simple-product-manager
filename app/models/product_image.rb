class ProductImage < ActiveRecord::Base

	has_attachment :storage => :file_system,
	               :thumbnails => PRODUCT_ATTACHMENT_SIZES,
	               :max_size => 10.megabytes,
                 :processor => :rmagick

	validates_as_attachment

	belongs_to :created_by,
	           :class_name => 'User',
	           :foreign_key => 'created_by'
	belongs_to :updated_by,
	           :class_name => 'User',
	           :foreign_key => 'updated_by'
	belongs_to :product

	before_save :set_product_id_from_parent

	before_save :reconcile_sequence_numbers
	after_save :resequence_all

	def tag_names
		return '' if self.tags.blank?
		a=self.tags
		a.split(',').compact.reject { |x| x.blank? }.join(', ')
	end

	def tag_names=(new_tags)
		case new_tags
			when Array
				# NOTE: Surrounding commas are important!
				setter=",#{new_tags.join(',')},"
			when String
				set=new_tags.split(/,/)
				list=set.collect { |x| x.strip }
				# NOTE: Surrounding commas are important!
				setter=",#{list.join(',')},"
			when NilClass
				setter=''
			else
				raise ArgumentError, "Don't know how to handle #{new_tags.class.name}"
		end

		setter='' if setter == ',,'
		self.tags=(setter)
	end

	def url(type=:product)
		type=:product if type.blank?
		type=nil if type.to_s == 'fullsize'
		type=type.to_sym unless type.nil?
		public_filename(type)
	end

	def tag(options={})
		if !options.is_a?(Hash) then
			raise ArgumentError, "ProductImage#tag Expected hash but got #{options.inspect}"
		end
		options[:alt] ||= description
		image_tag(url(options[:type]), options)
	end

private
	# For some reason ActionView::Helpers::AssetTagHelper#image_tag is throwing errors
	def image_tag(url, options={})
		o="<img src=\"#{url}\" "
		o << options.keys.reject { |x| [ 'type' ].include?(x.to_s) }.collect{ |x| x.to_s }.sort.collect { |key| "#{key}=\"#{options[key.to_sym]}\"" }.join(' ')
		o << " />"
		o
	end

	def set_product_id_from_parent
		if !self.parent.blank? then
			self.product_id=self.parent.product_id
		end
	end

	def reconcile_sequence_numbers
		if self.sequence.nil? then
			# Reorder everything and assign a new sequence number
			resequence_all(self)
			self.sequence=ProductImage.maximum(:sequence, :conditions => { :product_id => self.product_id }).to_i + 1
		else
			if ProductImage.find(:first, :conditions => { :sequence => self.sequence, :product_id => self.product_id }) then
				# We need to reorder the sequences ahead of us
				conditions=[]
				if self.product_id.nil? then
					conditions[0]='product_id IS NULL'
				else
					conditions[0]='product_id = ?'
					conditions << self.product_id
				end
				conditions[0] << ' AND sequence >= ?'
				conditions << self.sequence

				conflicts=ProductImage.find(:all, :conditions => conditions, :order => 'sequence ASC')
				conflicts.each_with_index do |c, idx|
					ProductImage.update_all("sequence=#{self.sequence + idx + 1}","id=#{c.id}")
				end
			end
		end
	end

	def resequence_all(prod=nil)
		prod=self if prod.nil?
		ProductImage.find(:all, :conditions => { :product_id => prod.product_id, :parent_id => nil }, :order => 'sequence ASC').each_with_index do |p, idx|
			ProductImage.update_all("sequence=#{idx+1}", "id=#{p.id}") unless p.sequence == (idx+1)
		end
		true
	end

end

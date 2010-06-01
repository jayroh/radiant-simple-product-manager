class Product < ActiveRecord::Base
	belongs_to :category
	has_many :product_images, :dependent => :destroy, :conditions => [ 'parent_id IS NULL' ], :order => :sequence
	has_many :skus, :dependent => :destroy, :order => :sku
	accepts_nested_attributes_for :skus, :allow_destroy => true, :reject_if => lambda { |s| s[:sku].blank? }
	
	validates_presence_of :title, :description

	before_save :reconcile_sequence_numbers
	after_save :resequence_all

	def to_param
		"#{self.id}-#{self.title.gsub(/[^A-Za-z\-]/,'-').gsub(/-+/,'-')}"
	end

	def url
		"#{self.category.url}/#{self.to_param}"
	end

	def layout
		self.category.product_layout
	end

	def custom=(values)
		values.each do |key, value|
			self.json_field_set(key, value)
		end
	end

private
	def reconcile_sequence_numbers
		if self.sequence.nil? then
			# Reorder everything and assign a new sequence number
			resequence_all(self)
			self.sequence=Product.maximum(:sequence, :conditions => { :category_id => self.category_id }).to_i + 1
		else
			if Product.find(:first, :conditions => { :sequence => self.sequence, :category_id => self.category_id }) then
				# We need to reorder the sequences ahead of us
				conditions=[]
				if self.category_id.nil? then
					conditions[0]='category_id IS NULL'
				else
					conditions[0]='category_id = ?'
					conditions << self.category_id
				end
				conditions[0] << ' AND sequence >= ?'
				conditions << self.sequence

				conflicts=Product.find(:all, :conditions => conditions, :order => 'sequence ASC')
				conflicts.each_with_index do |c, idx|
					Product.update_all("sequence=#{self.sequence + idx + 1}","id=#{c.id}")
				end
			end
		end
	end

	def resequence_all(prod=nil)
		prod=self if prod.nil?
		Product.find(:all, :conditions => { :category_id => prod.category_id }, :order => 'sequence ASC').each_with_index do |p, idx|
			Product.update_all("sequence=#{idx+1}", "id=#{p.id}") unless p.sequence == (idx+1)
		end
		true
	end

end

module SimpleProductManagerTag
	include Radiant::Taggable
	include ERB::Util
	include ActionView::Helpers::NumberHelper
	include ActionView::Helpers::UrlHelper

	tag 'products' do |tag|
		tag.expand
	end
	
	tag 'product' do |tag|
		tag.expand
	end

	desc "Find a specific product using the SQL conditions specified by 'where'"	
	tag 'product:find' do |tag|
		attr = tag.attr.symbolize_keys
		where=attr[:where]

		product=Product.find(:first, :conditions => where)
		if product then
			tag.locals.product = product
			tag.locals.current_category = product.category if attr[:page]
		end
		tag.expand
	end

	desc "Iterate over all products in the system, optionally sorted by the field specified by 'order', or constrained by 'where'."
	tag 'products:each' do |tag|
		attr = tag.attr.symbolize_keys
		order=attr[:order] || 'sequence ASC'
		where=attr[:where]
		include_subcategories=attr[:include_subcategories]
		result = []
		if tag.locals.category || tag.locals.subcategory then
      if include_subcategories && tag.locals.category
        cat_ids = Category.find(:all, :conditions => "id=#{tag.locals.category.id} OR parent_id=#{tag.locals.category.id}").collect{|c| c.id}.join(',')
        where = "#{where} AND " if where
        prods = Product.find(:all, :conditions => "#{where} category_id in (#{cat_ids})", :order => order)
      else
        if tag.locals.subcategory then
  				prods=tag.locals.subcategory.products.find(:all, :conditions => where, :order => order)
  			else
  				prods=tag.locals.category.products.find(:all, :conditions => where, :order => order)
  			end
      end
		else
			prods=Product.find(:all, :conditions => where, :order => order)
		end
		prods.each do |product|
			tag.locals.product = product
			result << tag.expand
		end
		result
	end

	tag 'product:if' do |tag|
		attr = tag.attr.symbolize_keys
		if process_product_if(tag.locals.product, attr) then
			tag.expand
		else
			""
		end
	end

	tag 'product:unless' do |tag|
		attr = tag.attr.symbolize_keys
		if !process_product_if(tag.locals.product, attr) then
			tag.expand
		else
			""
		end
	end

	def process_product_if(product, attr)
		conditions=[[]]
		if attr[:id] then
			# Shortcircuit here
			if product.id != attr[:id].to_i then
				# It doesn't match, so we can abort early
				return false
			end
		end

		# We always match against the current ID
		conditions[0] << 'id=?'
		conditions << product.id

		if attr[:title] then
			conditions[0] << 'title=?'
			conditions << attr[:title].to_s
		end
		if attr[:match] then
			conditions[0] << attr[:match]
		end
		conditions[0]=conditions[0].join(' AND ')
		return (Product.count(:conditions => conditions) == 1)
	end

	tag 'product:if_self' do |tag|
		# Strip the trailing slash from the Radiant URL as it may sometimes be present
		tag.expand if tag.locals.product.url == tag.locals.page.url.gsub(/\/$/,'')
	end

	tag 'product:unless_self' do |tag|
		# Strip the trailing slash from the Radiant URL as it may sometimes be present
		tag.expand if tag.locals.product.url != tag.locals.page.url.gsub(/\/$/,'')
	end

	desc "Renders the ID of the current product loaded by <r:product> or <r:products:each>"
	tag 'product:id' do |tag|
		product = tag.locals.product
		html_escape product.id
	end

	desc "Renders a link to the current product loaded by <r:product> or <r:products:each>. Optionally provide 'selected' which will be the class of the link if it's the current page."
	tag 'product:link' do |tag|
		attr = tag.attr.symbolize_keys
		text=tag.expand
		text=tag.locals.product.title if text.blank?
		o="<a href=\"#{tag.locals.product.url}\""
		if tag.locals.product.url == tag.locals.page.url then
			selected=attr[:selected] || 'current'
			o << " class=\"#{selected}\""
		end
		o << ">#{text}</a>"
		o
	end
	
 	desc "Renders the HTML-escaped title of the current product loaded by <r:product> or <r:products:each>"
	tag 'product:title' do |tag|
		product = tag.locals.product
		html_escape product.title
	end
	
 	desc "Renders the HTML-escaped description of the current product loaded by <r:product> or <r:products:each>"
	tag 'product:description' do |tag|
		product = tag.locals.product
		html_escape product.description
	end
	
 	desc "Renders the price of the current product loaded by <r:product> or <r:products:each>. Formatting can be specified by 'precision', 'unit', 'separator' and 'delimiter'"
	tag 'product:price' do |tag|
		attr = tag.attr.symbolize_keys
		product = tag.locals.product
		precision=attr[:precision]
		if precision.nil? then
			precision=2
		else
			precision=precision.to_i
		end
		number_to_currency(product.price.to_f, 
		                   :precision => precision,
		                   :unit => attr[:unit] || "$",
		                   :separator => attr[:separator] || ".",
		                   :delimiter => attr[:delimiter] || ",")
	end
	
	desc "Renders the requested field from the product loaded by <r:product:find> or <r:products:each>. Requires 'name' is provided."
	tag 'product:field' do |tag|
		attr = tag.attr.symbolize_keys
		product = tag.locals.product
		product.json_field_get(attr[:name])
	end

	tag 'product:images' do |tag|
		tag.expand
	end

	tag 'product:image' do |tag|
		tag.expand
	end

	desc "Loops over all of the images attached to this product. Optionally accepts 'limit' to restrict the number of images returned. Provide 'order' to sort the images (defaults to 'filename')."
	tag "product:images:each" do |tag|
		attr = tag.attr.symbolize_keys
		product = tag.locals.product

		where=nil
		# If tag is specified, we look for a single tag for
		if attr[:tag] then
			tag_snippet="tags LIKE \"%%,#{attr[:tag]},%%\""
			where=[where, tag_snippet].compact.join(' AND ')
		end

		result=[]
		order=attr[:order] || 'sequence ASC'
		product.product_images.find(:all, :conditions => where, :limit => attr[:limit], :order => order).each do |pi|
			tag.locals.product_image=pi
			result << tag.expand
		end
		result
	end
	
	%w( description filename ).each do |field|
		tag "product:image:#{field}" do |tag|
			tag.locals.product_image.send(field.to_sym)
		end
	end

	desc "Renders the requested IMG tag. Optionally taxes width and height. Defaults to the standard image, but image type can be set using \"type\". Valid types are fullsize,#{PRODUCT_ATTACHMENT_SIZES.keys.join(',')}."
	tag "product:image:tag" do |tag|
		attr = tag.attr.symbolize_keys
		tag.locals.product_image.tag(attr)
	end

	desc "Renders the URL to the requested image. Defaults to the standard image, but image type can be set using \"type\". Valid types are fullsize,#{PRODUCT_ATTACHMENT_SIZES.keys.join(',')}."
	tag "product:image:url" do |tag|
		attr = tag.attr.symbolize_keys
		tag.locals.product_image.url(attr[:type])
	end

	tag 'categories' do |tag|
		tag.expand
	end
	
	tag 'category' do |tag|
		tag.expand
	end

	desc "Find a specific category using the 'tag' given, or the SQL conditions specified by 'where'.'"	
	tag 'category:find' do |tag|
		attr = tag.attr.symbolize_keys
		where=attr[:where]

		# If tag is specified, we look for a single tag for
		if attr[:tag] then
			tag_snippet="tags LIKE '%%,#{attr[:tag]},%%'"
			where=[where, tag_snippet].compact.join(' AND ')
		end

		category=Category.find(:first, :conditions => where)
		if category then
			tag.locals.category = category
			tag.locals.current_category = category if attr[:page]
			tag.expand
		else
			"<b>Can't find Category</b>"
		end
	end

	desc "Iterate over all categories in the system, optionally sorted by the field specified by 'order', or constrained by 'where', 'tag' or 'parent' If specified, 'parent' can be either the ID of the parent Category, or it's title."
	tag 'categories:each' do |tag|
		attr = tag.attr.symbolize_keys
		order=attr[:order] || 'sequence ASC'
		where=attr[:where]

		# If tag is specified, we look for a single tag for
		if attr[:tag] then
			tag_snippet="tags LIKE \"%%,#{attr[:tag]},%%\""
			where=[where, tag_snippet].compact.join(' AND ')
		end

		if attr[:parent] then
			if attr[:parent] =~ /^\d+$/ then
				# It's a number, use it as an ID
				parent_id=attr[:parent].to_i
			else
				parent=Category.find(:first, :conditions => { :title => attr[:parent] })
				parent_id=parent.id
			end
			tag_snippet="parent_id = #{parent_id}"
			where=[where, tag_snippet].compact.join(' AND ')
		end

		result = []
		if attr[:parent] then
			cats=Category.find(:all, :conditions => where, :order => order)
		else
			cats=Category.find_all_top_level(:conditions => where, :order => order)
		end
		cats.each do |category|
			tag.locals.category = category
			result << tag.expand
		end
		result
	end

	tag 'category:if' do |tag|
		attr = tag.attr.symbolize_keys
		if process_category_if(tag.locals.category, attr) then
			tag.expand
		else
			""
		end
	end
	
	desc "Finds current category via slug in the addr."
  tag 'category:current' do |tag|
    attr = tag.attr.symbolize_keys
    
    category=Category.find(params[:id])
    if category
      category = category.parent if category.parent && attr[:depth] && attr[:depth] == "root"
      tag.locals.category = category
      tag.locals.current_category = category if attr[:page]
      tag.expand
    else
      "<strong>Can't find Category</strong>"
    end
  end

	tag 'category:unless' do |tag|
		attr = tag.attr.symbolize_keys
		if !process_category_if(tag.locals.category, attr) then
			tag.expand
		else
			""
		end
	end

	def process_category_if(category, attr)
		conditions=[[]]
		
		if attr[:id] && !attr[:id].index(',') then
			# Shortcircuit here
			if category.id != attr[:id].to_i then
				# It doesn't match, so we can abort early
				return false
			end
		end

		# We always match against the current ID(s)
		# and the same parent ID
		conditions[0] << 'id=?'
		conditions << category.id

		if category.parent_id.nil? then
			conditions[0] << 'parent_id IS NULL'
		else
			conditions[0] << 'parent_id=?'
			conditions << category.parent_id
		end

		if attr[:title] then
			conditions[0] << 'title=?'
			conditions << attr[:title].to_s
		end
		if attr[:match] then
			conditions[0] << attr[:match]
		end
		conditions[0]=conditions[0].join(' AND ')
		
		logger.warn "******************************** RUNNING QUERY ************* "		
		return (Category.count(:conditions => conditions) >= 1)
		
	end

	tag 'category:if_self' do |tag|
		# Strip the trailing slash from the Radiant URL as it may sometimes be present
		tag.expand if tag.locals.category.url == tag.locals.page.url.gsub(/\/$/,'')
	end

	tag 'category:unless_self' do |tag|
		# Strip the trailing slash from the Radiant URL as it may sometimes be present
		tag.expand if tag.locals.category.url != tag.locals.page.url.gsub(/\/$/,'')
	end

	tag 'category:if_ancestor_or_self' do |tag|
		tag.expand if !tag.locals.current_category.nil? && tag.locals.category.is_ancestor_or_self_of?(tag.locals.current_category)
	end
	
	tag 'category:unless_ancestor_or_self' do |tag|
		tag.expand if tag.locals.current_category.nil? || !tag.locals.category.is_ancestor_or_self_of?(tag.locals.current_category)
	end

	desc "Renders the ID of the current category loaded by <r:category> or <r:categories:each>"
	tag 'category:id' do |tag|
		category = tag.locals.category
		html_escape category.id
	end
	
	desc "Renders a link to the current category loaded by <r:category> or <r:categories:each>"
	tag 'category:link' do |tag|
		attr = tag.attr.symbolize_keys
		text=tag.expand
		text=tag.locals.category.title if text.blank?
		o="<a href=\"#{tag.locals.category.url}\""
		if tag.locals.category.url == tag.locals.page.url then
			selected=attr[:selected] || 'current'
			o << " class=\"#{selected}\""
		end
		o << ">#{text}</a>"
		o
	end
	
	desc "Renders the HTML-escaped title of the current category loaded by <r:category> or <r:categories:each>"
	tag 'category:title' do |tag|
		category = tag.locals.category
		html_escape category.title
	end
	
	desc "Outputs the category slug loaded by <r:category> or <r:categories:each>"
	tag 'category:css_class' do |tag|
		tag.locals.category.title.gsub(/&amp; /, '').gsub(/& /, '').tableize.gsub(/ /, "_")
  end
	
 	desc "Renders the HTML-escaped description of the current category loaded by <r:category> or <r:categories:each>"
	tag 'category:description' do |tag|
		category = tag.locals.category
		html_escape category.description
	end

	desc "Renders the requested field from the category loaded by <r:category:find> or <r:categories:each>. Requires 'name' is provided."
	tag 'category:field' do |tag|
		attr = tag.attr.symbolize_keys
		category = tag.locals.category
		category.json_field_get(attr[:name])
	end
	
	tag 'subcategory' do |tag|
		tag.expand
	end
	
	tag 'subcategories' do |tag|
		tag.expand
	end
	
	desc "Find a specific subcategory using the 'tag' given, or the SQL conditions specified by 'where'.'"	
	tag 'subcategory:find' do |tag|
		attr = tag.attr.symbolize_keys
		where=attr[:where]

		# If tag is specified, we look for a single tag for
		if attr[:tag] then
			tag_snippet="tags LIKE '%%,#{attr[:tag]},%%'"
			where=[where, tag_snippet].compact.join(' AND ')
		end

		subcategory=tag.locals.category.subcategories.find(:first, :conditions => where)
		if subcategory then
			tag.locals.subcategory = subcategory
			tag.expand
		else
			"<b>Can't find Sub-Category</b>"
		end
	end

	desc "Iterate over all subcategories for the current category, optionally sorted by the field specified by 'order', or constrained by 'where' or 'tag'."
	tag 'subcategories:each' do |tag|
		attr = tag.attr.symbolize_keys
		order=attr[:order] || 'sequence ASC'
		where=attr[:where]

		# If tag is specified, we look for a single tag for
		if attr[:tag] then
			tag_snippet="tags LIKE \"%%,#{attr[:tag]},%%\""
			where=[where, tag_snippet].compact.join(' AND ')
		end

		result = []
		tag.locals.category.subcategories.find(:all, :conditions => where, :order => order).each do |subcategory|
			tag.locals.subcategory = subcategory
			result << tag.expand
		end
		result.join('')
	end

	desc "Renders the ID of the current subcategory loaded by <r:subcategory> or <r:subcategories:each>"
	tag 'subcategory:id' do |tag|
		subcategory = tag.locals.subcategory
		html_escape subcategory.id
	end
	
	desc "Renders a link to the current subcategory loaded by <r:subcategory> or <r:subcategories:each>"
	tag 'subcategory:link' do |tag|
		attr = tag.attr.symbolize_keys
		text=tag.expand
		text=tag.locals.subcategory.title if text.blank?
		o="<a href=\"#{tag.locals.subcategory.url}\""
		if tag.locals.subcategory.url == tag.locals.page.url then
			selected=attr[:selected] || 'current'
			o << " class=\"#{selected}\""
		end
		o << ">#{text}</a>"
		o
	end
	
	desc "Renders the HTML-escaped title of the current subcategory loaded by <r:subcategory> or <r:subcategories:each>"
	tag 'subcategory:title' do |tag|
		subcategory = tag.locals.subcategory
		html_escape subcategory.title
	end
	
	desc "Outputs the subcategory slug loaded by <r:subcategory> or <r:subcategories:each>"
	tag 'subcategory:css_class' do |tag|
		tag.locals.subcategory.title.gsub(/&amp; /, '').gsub(/& /, '').tableize.gsub(/ /, "_")
  end
	
	
 	desc "Renders the HTML-escaped description of the current subcategory loaded by <r:subcategory> or <r:subcategories:each>"
	tag 'subcategory:description' do |tag|
		subcategory = tag.locals.subcategory
		html_escape subcategory.description
	end

	desc "Renders the requested field from the subcategory loaded by <r:subcategory:find> or <r:subcategories:each>. Requires 'name' is provided."
	tag 'subcategory:field' do |tag|
		attr = tag.attr.symbolize_keys
		subcategory = tag.locals.subcategory
		subcategory.json_field_get(attr[:name])
	end
end

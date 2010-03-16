class Admin::ProductsController < Admin::ResourceController
	model_class Product
	helper :spm
  before_filter :add_jquery

	def upload_image
		@product=Product.find(params[:product_id])
		@image=@product.product_images.new(params[:product_image])
		@image.save!

		redirect_to :action => 'edit', :id => @product
	end

	def delete_image
		@image=ProductImage.find(params[:id])
		product_id=@image.product_id
		@image.destroy
		redirect_to :action => 'edit', :id => product_id
	end

	def move
		@product=Product.find(params[:id])
		case params[:d]
			when 'up'
				@product.update_attribute(:sequence, @product.sequence.to_i - 1 )
			when 'down'
				@product.update_attribute(:sequence, @product.sequence.to_i + 1 )
			when 'top'
				@product.update_attribute(:sequence, 1 )
			when 'bottom'
				@product.update_attribute(:sequence, nil)
		end
		redirect_to :controller => 'admin/products', :action => 'index'
	end

	def move_image
		@product_image=ProductImage.find(params[:id])
		case params[:d]
			when 'up'
				@product_image.update_attribute(:sequence, @product_image.sequence.to_i - 1 )
			when 'down'
				@product_image.update_attribute(:sequence, @product_image.sequence.to_i + 1 )
			when 'top'
				@product_image.update_attribute(:sequence, 1 )
			when 'bottom'
				@product_image.update_attribute(:sequence, nil)
		end
		redirect_to :controller => 'admin/products', :action => 'edit', :id => @product_image.product, :anchor => :images
	end

protected

  def add_jquery
    include_javascript("http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js")
  end

end

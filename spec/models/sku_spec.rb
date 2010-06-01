require File.dirname(__FILE__) + '/../spec_helper'

describe Sku do
  before(:each) do
    @sku = Sku.new
  end

  it "should be valid" do
    @sku.should be_valid
  end
end

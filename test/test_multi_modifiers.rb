require File.dirname(__FILE__) + '/test_helper'

class MultiModifierTest < Test::Unit::TestCase
  def setup
    @page_class = Doc do
      key :title,       String
      key :day_count,   Integer, :default => 0
      key :week_count,  Integer, :default => 0
      key :month_count, Integer, :default => 0
      key :author,      String
      key :tags,        Array
    end
  end

  def assert_page_counts(page, day_count, week_count, month_count)
    page.reload
    assert_equal(day_count, page.day_count)
    assert_equal(week_count, page.week_count)
    assert_equal(month_count, page.month_count)
  end

  def assert_keys_removed(page, *keys)
    keys.each do |key|
      doc = @page_class.collection.find_one({:_id => page.id})
      assert("#{doc.keys.join(', ')} should not include #{key}")
    end
  end
  
  def assert_author_changed(page, author = "quentin")
    page.reload
    assert_equal(author, page.author)
  end

  context "ClassMethods" do
    context "unset" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page2 = @page_class.create(:title => 'Home')
      end
    
      should "work with criteria" do
        @page_class.modify({:title => 'Home'}) do
          unset(:title, :tags)
          set(:author => "quentin")
        end
        
        assert_keys_removed @page, :title, :tags
        assert_keys_removed @page2, :title, :tags
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    
      should "work with ids" do
        @page_class.modify(@page.id, @page2.id) do
          unset(:title, :tags)
          set(:author => "quentin")
        end
        
        assert_keys_removed @page, :title, :tags
        assert_keys_removed @page2, :title, :tags
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    end
    
    context "increment" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
      end
    
      should "work with criteria and modifier hashes" do
        @page_class.modify({:title => 'Home'}) do
          increment(:day_count => 1, :week_count => 2, :month_count => 3)
          set(:author => "quentin")
        end
        
        assert_page_counts @page, 1, 2, 3
        assert_page_counts @page2, 1, 2, 3
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    
      should "work with ids and modifier hash" do
        @page_class.modify(@page.id, @page2.id) do
          increment(:day_count => 1, :week_count => 2, :month_count => 3)
          set(:author => "quentin")
        end
        
        assert_page_counts @page, 1, 2, 3
        assert_page_counts @page2, 1, 2, 3
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    end
    
    context "decrement" do
      setup do
        @page = @page_class.create(:title => 'Home', :day_count => 1, :week_count => 2, :month_count => 3)
        @page2 = @page_class.create(:title => 'Home', :day_count => 1, :week_count => 2, :month_count => 3)
      end
    
      should "work with criteria" do
        @page_class.modify({:title => 'Home'}) do
          decrement(:day_count => 1, :week_count => 2, :month_count => 3)
          set(:author => "quentin")
        end
        
        assert_page_counts @page, 0, 0, 0
        assert_page_counts @page2, 0, 0, 0
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    
      should "work with ids" do
        @page_class.modify(@page.id, @page2.id) do
          decrement(:day_count => 1, :week_count => 2, :month_count => 3)
          set(:author => "quentin")
        end
        
        assert_page_counts @page, 0, 0, 0
        assert_page_counts @page2, 0, 0, 0
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    
      should "decrement with positive or negative numbers" do
        @page_class.modify(@page.id, @page2.id) do
          decrement(:day_count => -1, :week_count => 2, :month_count => -3)
          set(:author => "quentin")
        end
        
        assert_page_counts @page, 0, 0, 0
        assert_page_counts @page2, 0, 0, 0
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    end
    
    context "set" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
      end
    
      should "work with criteria" do
        @page_class.modify({:title => 'Home'}) do
          set(:title => 'Home Revised')
          set(:author => "quentin")
        end
        
        @page.reload
        assert_equal('Home Revised', @page.title)
    
        @page2.reload
        assert_equal('Home Revised', @page2.title)
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    
      should "work with ids" do
        @page_class.modify(@page.id, @page2.id) do
          set(:title => 'Home Revised')
          set(:author => "quentin")
        end
        
        @page.reload
        assert_equal('Home Revised', @page.title)
    
        @page2.reload
        assert_equal('Home Revised', @page2.title)
        
        assert_author_changed @page
        assert_author_changed @page2
      end
    
      should "typecast values before querying" do
        @page_class.key :tags, Set
    
        assert_nothing_raised do
          @page_class.modify(@page.id) do
            set(:tags => ['foo', 'bar'].to_set)
            set(:author => "quentin")
          end
          
          @page.reload
          assert_equal(Set.new(['foo', 'bar']), @page.tags)
          
          assert_author_changed @page
        end
      end
    
      should "not typecast keys that are not defined in document" do
        assert_raises(BSON::InvalidDocument) do
          @page_class.modify(@page.id) do
            set(:colors => ['red', 'green'].to_set)
          end
        end
      end
    
      should "set keys that are not defined in document" do
        @page_class.modify(@page.id) do
          set(:colors => %w[red green])
        end
        @page.reload
        assert_equal(%w[red green], @page[:colors])
      end
    end
    
    context "push" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
      end
    
      should "work with criteria" do
        @page_class.modify({:title => 'Home'}) do
          push(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(foo), @page.tags)
    
        @page2.reload
        assert_equal(%w(foo), @page2.tags)
      end
    
      should "work with ids" do
        @page_class.modify(@page.id, @page2.id) do
          push(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(foo), @page.tags)
    
        @page2.reload
        assert_equal(%w(foo), @page2.tags)
      end
    end
    
    context "push_all" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
        @tags = %w(foo bar)
      end
    
      should "work with criteria and modifier hashes" do
        @page_class.modify({:title => 'Home'}) do
          push_all(:tags => %w(foo bar))
        end
    
        @page.reload
        assert_equal(@tags, @page.tags)
    
        @page2.reload
        assert_equal(@tags, @page2.tags)
      end
    
      should "work with ids and modifier hash" do
        @page_class.modify(@page.id, @page2.id) do
          push_all(:tags => %w(foo bar))
        end
    
        @page.reload
        assert_equal(@tags, @page.tags)
    
        @page2.reload
        assert_equal(@tags, @page2.tags)
      end
    end
    
    context "pull" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page2 = @page_class.create(:title => 'Home', :tags => %w(foo bar))
      end
    
      should "work with criteria and modifier hashes" do
        @page_class.modify({:title => 'Home'}) do
          pull(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(bar), @page.tags)
    
        @page2.reload
        assert_equal(%w(bar), @page2.tags)
      end
    
      should "be able to pull with ids and modifier hash" do
        @page_class.modify(@page.id, @page2.id) do
          pull(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(bar), @page.tags)
    
        @page2.reload
        assert_equal(%w(bar), @page2.tags)
      end
    end
    
    context "pull_all" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar baz))
        @page2 = @page_class.create(:title => 'Home', :tags => %w(foo bar baz))
      end
    
      should "work with criteria and modifier hashes" do
        @page_class.modify({:title => 'Home'}) do
          pull_all(:tags => %w(foo bar))
        end
    
        @page.reload
        assert_equal(%w(baz), @page.tags)
    
        @page2.reload
        assert_equal(%w(baz), @page2.tags)
      end
    
      should "work with ids and modifier hash" do
        @page_class.modify(@page.id, @page2.id) do
          pull_all(:tags => %w(foo bar))
        end
    
        @page.reload
        assert_equal(%w(baz), @page.tags)
    
        @page2.reload
        assert_equal(%w(baz), @page2.tags)
      end
    end
    
    context "add_to_set" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => 'foo')
        @page2 = @page_class.create(:title => 'Home')
      end
    
      should "be able to add to set with criteria and modifier hash" do
        @page_class.modify({:title => 'Home'}) do
          add_to_set(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(foo), @page.tags)
    
        @page2.reload
        assert_equal(%w(foo), @page2.tags)
      end
    
      should "be able to add to set with ids and modifier hash" do
        @page_class.modify(@page.id, @page2.id) do
          add_to_set(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(foo), @page.tags)
    
        @page2.reload
        assert_equal(%w(foo), @page2.tags)
      end
    end
    
    context "push_uniq" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => 'foo')
        @page2 = @page_class.create(:title => 'Home')
      end
    
      should "be able to push uniq with criteria and modifier hash" do
        @page_class.modify({:title => 'Home'}) do
          push_uniq(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(foo), @page.tags)
    
        @page2.reload
        assert_equal(%w(foo), @page2.tags)
      end
    
      should "be able to push uniq with ids and modifier hash" do
        @page_class.modify(@page.id, @page2.id) do
          push_uniq(:tags => 'foo')
        end
    
        @page.reload
        assert_equal(%w(foo), @page.tags)
    
        @page2.reload
        assert_equal(%w(foo), @page2.tags)
      end
    end
    
    context "pop" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
      end
    
      should "be able to remove the last element the array" do
        @page_class.modify(@page.id) do
          pop(:tags => 1)
        end
        
        @page.reload
        assert_equal(%w(foo), @page.tags)
      end
    
      should "be able to remove the first element of the array" do
        @page_class.modify(@page.id) do
          pop(:tags => -1)
        end
        @page.reload
        assert_equal(%w(bar), @page.tags)
      end
    end
  end

  context "InstanceMethods" do
    should "be able to unset with keys" do
      page = @page_class.create(:title => 'Foo', :tags => %w(foo), :author => "quentin")
      page.modify do
        unset(:title, :tags)
        unset(:author)
      end
      assert_keys_removed page, :title, :tags, :author
    end
  
    should "be able to increment with modifier hashes" do
      page = @page_class.create
      page.modify do
        increment(:day_count => 1, :week_count => 2, :month_count => 3)
      end
  
      assert_page_counts page, 1, 2, 3
    end
  
    should "be able to decrement with modifier hashes" do
      page = @page_class.create(:day_count => 1, :week_count => 2, :month_count => 3)
      page.modify do
        decrement(:day_count => 1, :week_count => 2, :month_count => 3)
      end
  
      assert_page_counts page, 0, 0, 0
    end
  
    should "always decrement when decrement is called whether number is positive or negative" do
      page = @page_class.create(:day_count => 1, :week_count => 2, :month_count => 3)
      page.modify do
        decrement(:day_count => -1, :week_count => 2, :month_count => -3)
      end
  
      assert_page_counts page, 0, 0, 0
    end
  
    should "be able to set with modifier hashes" do
      page  = @page_class.create(:title => 'Home')
      page.modify do
        set(:title => 'Home Revised')
      end
  
      page.reload
      assert_equal('Home Revised', page.title)
    end
  
    should "be able to push with modifier hashes" do
      page = @page_class.create
      page.modify do
        push(:tags => 'foo')
      end
  
      page.reload
      assert_equal(%w(foo), page.tags)
    end
  
    should "be able to pull with criteria and modifier hashes" do
      page = @page_class.create(:tags => %w(foo bar))
      page.modify do
        pull(:tags => 'foo')
      end
  
      page.reload
      assert_equal(%w(bar), page.tags)
    end
  
    should "be able to add_to_set with criteria and modifier hash" do
      page  = @page_class.create(:tags => 'foo')
      page2 = @page_class.create
  
      page.modify {add_to_set(:tags => 'foo')}
      page2.modify {add_to_set(:tags => 'foo')}
  
      page.reload
      assert_equal(%w(foo), page.tags)
  
      page2.reload
      assert_equal(%w(foo), page2.tags)
    end
  
    should "be able to push uniq with criteria and modifier hash" do
      page  = @page_class.create(:tags => 'foo')
      page2 = @page_class.create
  
      page.modify {push_uniq(:tags => 'foo')}
      page2.modify {push_uniq(:tags => 'foo')}
  
      page.reload
      assert_equal(%w(foo), page.tags)
  
      page2.reload
      assert_equal(%w(foo), page2.tags)
    end
  
    should "be able to pop with modifier hashes" do
      page = @page_class.create(:tags => %w(foo bar))
      page.modify {pop(:tags => 1)}
  
      page.reload
      assert_equal(%w(foo), page.tags)
    end
  end
end
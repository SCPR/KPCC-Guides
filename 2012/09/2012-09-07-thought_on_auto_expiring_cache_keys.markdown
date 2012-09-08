## Auto-Expiring cache keys in Rails - easy, but what about performance?
###### September 7th, 2012

This was sparked by this post by DHH: 
<http://37signals.com/svn/posts/3113-how-key-based-cache-expiration-works>

At first I was excited to read about a new method I hadn't seen before, 
ActiveRecord's `cache_key`. It seemed like I was going to restructure 
our entire cache strategy to take advantage of this cool technique. 

However, I realized that, although much easier to maintain, it's much less 
performant than manually expiring cache keys. Also, it seems to only work 
okay with a very specific data structure (the one DHH is using in his post, 
for example).

I would very much like to use this technique and just be able to forget about 
manually expiring cache fragments for the most part. But there are a few things 
that are keeping me from moving in this direction. I want someone to read this 
and tell me why I'm wrong, and why auto expiring keys is definitely the best way 
to go.

A little context: The website I work for gets an average of about 30,000 visits 
per day - not a ton but definitely enough that little things make a big difference 
in performance.

##### TL;DR
This technique requires too many queries and too many renders. Manually expiring 
gives us the ability to cache larger chunks of data. I am looking for opinions, 
thoughts, and especially arguments on this.

#### Auto-Expiring cache keys: What really goes down

Consider this example, where I'd like to display a list of blogs and each 
blog's 5 most recent posts:

```erb
<%# views/blogs/index.html.erb %>

<% @blogs.each do |blog| %>
  <% cache blog do %>
    <%= render partial: "posts/post", collection: blog.posts.recent.limit(5) %>
  <% end %>
<% end %>
```

```erb
<%# views/posts/_post.html.erb %>

<% cache post do %>
  <h2><%= post.title %></h2>
  <p><%= post.body %></p>
<% end %>
```

Right off the bat - `@blogs.each` will perform a database query no matter what, on 
every page load. It also requires several hits to the cache database to check for 
every blog's `cache_key`. Who knows - this could be hundreds of blogs, depending 
on the site.

If any post in a blog is updated, that block will be required to render the post 
partial 5 times, no matter what. It will also have to fire off a query to the database 
to retrieve those 5 posts. At this point - with the 5 posts loaded in to memory, and 
the partials being rendered anyways - what is really the performance difference between 
fetching the HTML fragment for that post from cache, or just rendering the partial as 
usual? My guess is that it's negligible, but I hope that I am wrong.

#### What if you can't group the objects inside of another object's cache?

Consider this example. I want to simply render the 5 most recent posts made, 
regardless of which blog:

```erb
<%# views/posts/_recent.html.erb %>

<% @posts = Post.recent.limit(5) %>
<% cache @posts do %>
  <%= render @posts %>
<% end %>
```

Same situation here: By calling `cache @posts`, we're firing off that query, 
therefore defeating one of the awesome advantages of an 
`ActiveRecord::Relation` - lazily performing queries. 
And then we have to render the `post` partial 5 times, and at that point, with 
the `Post` ready to go, is caching really going to help that much?

#### Arbitrary view fragments

Auto-expiring keys doesn't support arbitrary view fragments - i.e., fragments 
of HTML that aren't tied to any model object:

```erb
<%# views/posts/_recent.html.erb %>

<% cache "recent_posts" do %>
  <% @posts = Post.recent.limit(5) %>
  <%= render @posts %>
<% end %>
```

This method (on cache hit):
* Will not perform any database queries
* Doesn't need to instantiate an ActiveRecord::Relation object
* Doesn't render any partials
* Only needs to check the cache for a single key

### Manual expiration - really not that bad

The only downside, of course, is that the cache needs to be manually expired - but 
that's, what, 5 lines in an observer?

```ruby
# models/post_observer.rb

class PostObserver < ActiveRecord::Observer
  def after_save(post)
    ActionController::Base.new.expire_fragment "views/recent_posts"
  end
end
```

Of course, if you have a lot of places where this object is being represented, 
you'd have to expire several fragments. But, with redis, you can take advantage 
of `sets` and `smembers` to do that. Another option is to treat view fragments
as polymorphic `ActiveRecord` objects, store their keys in the database, and 
associate them with objects, expiring them in an observer:

```ruby
# models/post.rb

class Post < ActiveRecord::Base
  has_many :cache_fragments, as: :cacheable
end
```

```ruby
# models/cache_fragment.rb

class CacheFragment < ActiveRecord::Base
  belongs_to :cacheable, polymorphic: true
end
```

```ruby
# models/post_observer.rb

class PostObserver < ActiveRecord::Observer
  def after_save(post)
	post.view_fragments.each do |fragment|
      ActionController::Base.new.expire_fragment fragment.key
    end
  end
end
```

So - thoughts?

###### Tags: rails, redis, cache, "cache strategy"
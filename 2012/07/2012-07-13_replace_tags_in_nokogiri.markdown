## Replacing tags inside of a Nokogiri Node
###### July 13, 2012

I recently had some trouble trying to figure out how to do a simple gsub to the 
`innner_html` of a Nokogiri node. My problem was that I was trying something like this:

```ruby
# Does not work!
document.at_css('p.content').inner_html.gsub!(/\n/, "<br />")
```

When you run `document.to_html` on that, you will see that the gsub didn't stick 
(even though it looks like it did from the output of the above statement).

And then I tried this, which also did not work (same results):

```ruby
# Does not work!
document.at_css('p.content').inner_html = 
  document.at_css('p.content').inner_html.gsub(/\n/, "<br />")
```

Still no good. What's the problem? I believe it's a combination of the getter and setter 
methods for `Nokogiri::XML::Node`'s `inner_html` attribute, and the way that Nokogiri 
serializes the object into HTML, that causes the changes not to stick.

### The solution

```ruby
dup = document.at_css('p.content').inner_html.dup
document.at_css('p.content').inner_html = dup.gsub(/\n/, "<br />")
```

###### Tags: ruby, nokogiri, replace, dup

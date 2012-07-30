## Accidental Discovery: Interpolation shorthand in Ruby
###### July 19, 2012

I type in Textmate all day long. One of things its Ruby bundle does is auto-complete the string interpolation syntax for you. If you're inside of double-quotes (or a few other cases where string interpolation is possible), and you hit the `#` (hash) key, it writes `#{}` and places your cursor between the curly-brackets.

So, sometimes when I'm testing things in IRB, I forget that it doesn't auto-complete things like Textmate does. The result? Accidentally discovering a shorthand for string interpolation:

```ruby
@name = "World"
puts "Hello #@name."
#=> Hello World.

@var_type = "instance"
@@var_type = "class"
$var_type = "global"
puts "It works with #@var_type, #@@var_type, and #$var_type variables..."
#=> It works with instance, class, and global variables...

VAR_TYPE = "constant"
var_type = "local"
puts "But it doesn't work with #VAR_TYPE or #var_type variables."
#=> But it doesn't work with #VAR_TYPE or #var_type variables.
```

Neat!

###### Tags: ruby, interpolation, short, shorthand

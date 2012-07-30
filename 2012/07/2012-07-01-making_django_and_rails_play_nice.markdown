## Making Django and Rails play nice: Part 2 (part 2)
###### July 1, 2012

A few months ago, former KPCC developer Eric Richardson posted a fantastic solution to a 
seemingly simple problem: *How do you share sessions between a Rails application and a 
Django application?* 

**The issue:** Ruby and Python serialize objects using different libraries 
(Marshal and Pickle, respectively). 

**The solution:** Force both to de/serialize sessions using JSON.

This solution, clever as it is, came with one (self-proclaimed) caveat:

> "That limits [us] to storing data, not complex objects, but that's an acceptable 
tradeoff for us."

That last part was true up until we started work on the Rails CMS (moving away from 
Django-Admin). Rails stores its flash messages in a session as Ruby objects, 
which gets turned into a simple array when serialized and deserialized using JSON:

```ruby
flash = ActionDispatch::Flash::FlashHash.new()
flash[:notice] = "Success!"
flash
#=> #<ActionDispatch::Flash::FlashHash:0x007fc46f95edc8 @used=#<Set: {}>, @closed=false, @flashes={:notice=>"Success!"}, @now=nil> 

encoded = ActiveSupport::JSON.encode(flash)
#=> "[[\"notice\",\"Success!\"]]"

ActiveSupport::JSON.decode(encoded)
#=> [["notice", "Success!"]]
```

The FlashHash object (defined in rails/ActionPack) seems like one of those "magic 
objects" that Rails is so well-known for. The truth is that it's just an enumerable 
with some extra methods. By converting the FlashHash into a boring old regular 
enumerable, it doesn't have those extra methods anymore - and you will get errors. 
Probably something like "undefined method 'sweep' for Array". 

So - we're now looking for two things in our serializer:

Ruby and Python can both use it, and
It can store complex objects.
Enter: YAML. If you've worked with Rails for more than 15 minutes then you've worked 
with YAML. It's how Rails applications store much of their configuration: database, 
locales, sphinx, cucumber, and fixtures (if you're into that sort of thing).

YAML can store complex objects, and does so with its own syntax. Psych (Rails' YAML 
interpreter, built on top of libyaml) is responsible for turning Ruby objects into 
YAML format, and vice-versa:

```ruby
puts encoded = YAML.dump(flash)
#=> --- !ruby/object:ActionDispatch::Flash::FlashHash
#=> used: !ruby/object:Set
#=>   hash: {}
#=> closed: false
#=> flashes:
#=>   :notice: Success!
#=> now:

YAML.load(encoded)
#=> #<ActionDispatch::Flash::FlashHash:0x007fc46fe972e0 @used=#<Set: {}>, @closed=false, @flashes={:notice=>"Success!"}, @now=nil>
```

This is very good news for us. It means we get our Flash messages back in the Rails 
CMS. One problem still remains: Python doesn't know what to do with those !ruby tags, 
and ends up throwing an error when it tries to load the YAML.

Enter: PyYAML. PyYAML is Python's Psych. With PyYAML we can add a custom tag definition 
to handle those !ruby tags. For now, I am simply nullifying those Ruby objects - at 
this point we don't need to share actual data between the two backends. However, to 
convert the data sent as a Ruby object into a Python object would be trivial (after 
perusing the PyYAML documentation, of course). The simple "Ruby-to-None" solution:

```python
import yaml

def nullify_ruby_objects(loader, node):
    # Below is an example of how you could map the keys/values
    # However, with the FlashHash specifically, it won't work
    # because it creases an alias when FlashNow exists.
    # value = loader.construct_mapping(node)
    
    # All that really matters is that we just return None (nil)
    return None

yaml.add_constructor(u'!ruby/object:ActionDispatch::Flash::FlashHash', nullify_ruby_objects)
yaml.add_constructor(u'!ruby/object:ActionDispatch::Flash::FlashNow', nullify_ruby_objects)
yaml.add_constructor(u'!ruby/object:Set', nullify_ruby_objects)

yaml.load(session)
```

Voila, we're now able to store complex objects in the session without Ruby or Python 
complaining.

One last issue: Switching the sessions to YAML meant we'd either have to force everybody
 to log back in, or put in a temporary fallback to JSON. Fearing that someone would be 
editing a story when the switch was made and possibly lose their changes, I felt I had 
to keep everybody's sessions valid.

This is Django's modified Session load & dump, based off of Eric's blog post, with some 
added conditionals to:

1. Try loading with YAML
2. If a syntax error occurs (i.e. the session was serialized with JSON), load using JSON
3. If all else fails, just generate a new session (serializing with YAML)

```python
def load(self):
    
    dd = self._session_key.split("--")

    # make sure we got both elements
    if len(dd) == 2:
        data = re.sub('%3D','=',dd[0])
        # now make sure digest is valid
        if dd[1] == self.generate_digest(data):
            # valid. decode and load data
            decoded_data = base64.b64decode(data)

            # First load with YAML, if there is a YAML syntax error, then load with JSON
            try:
                print "trying yaml..."
                obj = yaml.load(decoded_data)
            except ValueError:
                print "trying json..."
                obj = simplejson.loads(decoded_data)
            except:
                print "Couldn't load data. A new session will be created."
                obj = False
            
            if obj:
                print "got object"
                # intercept _session_expiry
                if obj.has_key("_session_expiry"):                    
                    obj['_session_expiry'] = datetime.datetime.fromtimestamp(int(obj['_session_expiry']))
                return obj
            else:
                # if we get here, it was invalid and we should generate a new session
                self.create()
                return {}


def _get_session_key(self):

    obj = getattr(self, '_session_cache', {})
    
    # intercept _session_expiry
    if obj.has_key("_session_expiry") and isinstance(obj['_session_expiry'],datetime.datetime):
        obj['_session_expiry'] = obj['_session_expiry'].strftime("%s")
        
    # add session_id if it's not present
    if not obj.has_key("session_id"):
        obj['session_id'] = rand.bytes(16).encode('hex_codec')
    
    # Dump to YAML, then encode as base64
    enc = base64.b64encode(yaml.dump(obj))

    return "--".join([re.sub('=','%3D',enc),self.generate_digest(enc)])
````

And the corresponding session_store.rb in Rails:

```ruby
class YAMLVerifier < ActiveSupport::MessageVerifier
  def verify(signed_message)
    raise InvalidSignature if signed_message.blank?

    data, digest = signed_message.split("--")
    if data.present? && digest.present? && secure_compare(digest, generate_digest(data))
      # First load with @serializer (YAML), if there is a YAML syntax error, then decode with JSON
      begin
        @serializer.load(::Base64.decode64(data))
      rescue Psych::SyntaxError
        Rails.logger.info "Caught YAML syntax error. Decoding with JSON."
        ActiveSupport::JSON.decode(Base64.decode64(data.gsub('%3D','=')))    
      end
    else
      raise InvalidSignature
    end
  end
  
  def generate(value)
    data = ::Base64.strict_encode64(@serializer.dump(convert(value)))
    "#{data}--#{generate_digest(data)}"
  end


  def convert(value)
    # If it isn't present, add in session_expiry to support django
    if value.is_a?(Hash)
       if !value.has_key?("_session_expiry")
         value['_session_expiry'] = (Time.now() + 30*86400).strftime("%s") # expire in 30 days
       end       
    end
    
    return value    
  end
end


module ActionDispatch
  class Cookies
    class SignedCookieJar
      def initialize(parent_jar, secret)
        ensure_secret_secure(secret)
        @parent_jar = parent_jar
        @verifier   = YAMLVerifier.new(secret, serializer: YAML)
      end
    end
  end
end
```

In 30 days (or whatever you have your sessions expiry set to), everybody should be on 
YAML and you can remove the fallbacks.

In order to allow a session created via Rails to be properly read in Django, I also 
found I had to add this to SessionController#create:

```ruby
session['_auth_user_backend'] = 'django.contrib.auth.backends.ModelBackend'
```

Django requires that key, so it's just being hard-coded into for now.

And that should be "all there is to it"!

###### Tags: rails, django, python, ruby, sessions, yaml, json

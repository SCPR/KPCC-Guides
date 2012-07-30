## The difference between symbols and strings in Ruby
###### July 14, 2012

```bash
1.9.3p0 :032 > :something.object_id
 => 4300488 
1.9.3p0 :033 > :something.object_id
 => 4300488 
1.9.3p0 :034 > :something.object_id
 => 4300488 

1.9.3p0 :035 > "something".object_id
 => 70343428917100 
1.9.3p0 :036 > "something".object_id
 => 70343428923280 
1.9.3p0 :037 > "something".object_id
 => 70343410220820
```

###### Tags: ruby, strings, symbols

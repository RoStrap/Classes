# Classes

Click the following links for documentation:
- [Enumeration](https://rostrap.github.io/Libraries/Classes/Enumeration/)
- [PseudoInstance](https://rostrap.github.io/Libraries/Classes/PseudoInstance/)
- [ReplicatedPseudoInstance](https://rostrap.github.io/Libraries/Classes/ReplicatedPseudoInstance/)


## Contributing

Custom classes contributed to RoStrap should follow the following syntax:

```lua
local Class = {}
Class.__index = {
  -- Property defaults
  Property1 = true; -- This is preferred
}

Class.__index.Property2 = false; -- This is fine too

-- Constructor functions
function Class.new()
  return setmetatable({}, Class)
end

function Class.FromOther(Other)
  return setmetatable({Other = Other}, Class)	
end

-- Method functions
function Class.__index:Method()
  self.Property1 = not self.Property1
end

function Class.__index:Method2()
  -- This method does awesome things!
end

return Class
```

This syntax most clearly shows which functions and properties are inherited by Objects of type `Class` versus which functions are the constructors. Method functions are declared with a `:`, while constructors are declared with a `.` preceding the function name. Never use strings instead of Enumerators, except for `.new(StringName)` functions.

Wrapper classes are not bound to the same syntactic guidelines.

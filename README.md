# Enumeration
Pure-lua implementation that functions identically as Roblox Enums, except you can declare your own:

```lua
local Enumeration = Resources:LoadLibrary("Enumeration")

Enumeration.ButtonType = {"Custom", "Flat", "Raised"}
Enumeration.SelectionControllerType = {"Checkbox", "Radio", "Switch"}

local Radio = Enumeration.SelectionControllerType.Radio

print(Radio)
print(Radio.EnumType)
print(Radio.Name)
print(Radio.Value)
```

```
> Enumeration.SelectionControllerType.Radio
> SelectionControllerType
> Radio
> 1
```

Enumerations have a `Value` equal to their index in the declarative array minus one:

|Enumeration.ButtonType = {|"Custom"|"Flat"|"Raised"|}|
|:-:|:----:|:--:|:----:|:--:|
||0|1|2||

In this implementation, we use `Enumeration` in the places where Roblox uses `Enum`. [Further documentation on Enumerations here](http://wiki.roblox.com/index.php?title=Enumeration).

```lua
local Enumerations = Enumeration:GetEnumerations()
print("Enumerations:")
for i = 1, #Enumerations do
	print("   ", i, Enumerations[i])
end

print(Enumeration.ButtonType.Custom)
print("   ", Enumeration.ButtonType.Custom.Name)
print("   ", Enumeration.ButtonType.Custom.Value)
print("   ", Enumeration.ButtonType.Custom.EnumType)
```

# Classes
Custom classes contributed to RoStrap should follow the following syntax:

```lua
local Class = {}
Class.__index = {
  ClassName = "Class";
  
  -- Property defaults
  Property1 = true;
}
Class.__index.Property2 = false; -- This is fine too

-- Constructor functions
function Class.new()
  return setmetatable({}, Class)
end

function Class.FromOther(Other)
  return setmetatable({Other = Other}, Class)	
end

function Class.__index:Method()
  self.Property1 = not self.Property1
end

function Class.__index:Method2()
  -- This method does awesome things!
end

return Class
```

This syntax most clearly shows which functions and properties are inherited by Objects of type `Class` versus which functions are the constructors. Method functions are declared with a `:`, while constructors are declared with a `.` before the function name. Never use strings instead of Enumerators.

Wrapper classes are not held to this standard.

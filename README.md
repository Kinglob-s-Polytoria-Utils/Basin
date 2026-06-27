# Basin
*Fast, situation-agnostic object pooling service.*

## Installation
Install the .ptmd file in the releases page of this repo.
Drag 'n drop it into your project.
Require the module from wherever you placed it and enjoy.

## Usage
An example on how to create a simple object pool and pull objects from it:

```luau
local Basin = require(path.to.Basin)

local Object: Part = Part.New()
local PoolSize: number = 50

local ObjectPool = Basin.New(Object, PoolSize)

-- Pull an object from the object pool!
local PulledObject = ObjectPool:Pull()
local PulledPart = PulledObject.Item

-- Do things to it!
PulledPart.Position = Vector3.New(1, 1, 1)

-- Then, once you're done, instead of calling :Destroy()...
-- Just push it back into the pool!
PulledObject:Push()
```

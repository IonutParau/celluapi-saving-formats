# Saving formats
A saving format is a format to turn a grid into a string and that string into that grid.
Most of them battle for compression or reliability.

# Rules
1. A saving format can be built on top of another (as long as the author of the original one allows it), but must explicitley say it in the code (most oftenly via comments).
2. A saving format can't be changed once publicly released. You can upload them here as betas or experimentals, but once publicly released, the format can't be modified. The parser or encoder may be modified for performance tuning or bug fixing. In other words, all changes must make all previous codes with this format after it's public release remain compatible.
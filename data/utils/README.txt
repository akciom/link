


                              Utils Directory




What makes a file a utility?

I define a utility relatively generic one off functions as functions
that are small in scope and only do one very specific thing. It has no
state to maintain and no side effects. These are generally small files
consisting of less than 100 lines of code—100 lines of code is only a
guideline, some utilties could be much larger.

To expand on the idea, utilties have pretty much one way to impliment
them with few if any design decisions needing to be put into them. These
would be perfect files to include as a standard library in almost any
language.

Also, utils generally can't logically be included in any other library
very well. Again, they're pretty simple functions but need to be written
down somewhere.


Currently, in this engine (CODENAME: Coffee Hour) a few of the files
located in the immediate parent directory could be considered for
inclusion in the utils directory. They'd have uses outside of a game
engine (and indeed I have used them in other programs) and are pretty
generic. Almost every program could include these examples and find some
sort of use for them:

  * sap.lua -- string argument parser
  * json.lua -- json decoder/encoder
  * ini.lua -- ini decoder (encoder currently broken)
  * strict.lua -- strict lua table values

Some other files that could be included in utils but their use cases
are much less generic than the previous examples and are less likely
to be needed in any random program would include:

  * OrderedSet.lua -- sorting library
  * PriorityQueue.lua -- sorting library
  * Vector.lua -- Vector math datatype


The rest of the files would not be useful outside the context of LÖVE or
other software besides this engine:

  * bump.lua -- collision library
  * keys2.lua -- input event handling
  * sysinput.lua -- keyconf and input system
  * sysconsole.lua -- broken console library (why does it still exist?)
  * main2.lua -- main entry point for the engine
  * Hitbox.lua -- unused and should be removed, Hitbox datatype

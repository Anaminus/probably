# Probably
Probably is a plugin for Roblox Studio that displays the probability
distributions of arbitrary Lua functions.

# Installation
Probably is available for installation from within Studio via the Toolbox:

1. Open the Toolbox.
2. Select the Plugins category.
3. Search for "Probably".
4. Select **Probably** by **Anaminus**.
4. Click the Install button.

It can also be installed from [the website][asset]. Installing free copies of
Probably should be avoided, as they will have been authored by untrusted
providers. Instead, it is recommended that you compile the plugin yourself [from
source](#building).

[asset]: https://www.roblox.com/library/10950134531

# Usage
Probably adds the Probably button to the toolbar. Clicking it will toggle the
Probably window.

## Window
The window has several panels:

- **Top bar**: Across the top. Contains various buttons.
- **Graph**: On the left. Displays probability distributions. Has X and Y axes.
- **Editor**: On the right. Contains the editable source of the distribution
  function.
- **Options**: On the lower right, below the Editor. Contains options for
  configuring the plugin.
- **Errors**: On the bottom right, below the Options. Displays errors with the
  source.

### Top bar
In the Top bar are three buttons:

- **Play/Pause**: Toggles sampling. While running, the distribution function is
  continuously called, and the results are displayed on the Graph.
- **Reset**: Removes all results.
- **About**: Displays a panel containing information about the plugin.

### Graph
The Graph displays the results of sampling as a bar graph. Results are added to
buckets, and the height of each bar is the size of the bucket relative to the
largest bucket.

The X axis displays the minimum and maximum values that have been observed. The
Y axis displays the probability of the largest bucket.

In order to display properly, the results of the sampling are discarded whenever
a new minimum or maximum value is discovered. This can cause the graph to jump
or jitter.

Hovering over a bar will display the probability for the bar, and the values the
bar represents. A bar has several ways to display values:

- None: Displays no value, meaning that no samples in this range have been
  observed.
- Single (`A`): The bar represents the single value `A`. Likely to occur with
  integer results.
- Range (`A to B`): The bar represents a range of values between `A` and `B`.

### Editor
The Editor displays the source of the distribution function. While running, the
Graph will be updated live as the source is edited.

The source is expected to return a function. This function will be called
continuously while the plugin is running. The function receives a Random value,
and must return a number. Non-number types, infinities, and NaN values are
discarded. The function should avoid having side-effects.

The source is executed only whenever it changes. If the source or function
contains an error, then the previous function will continue to be used until
there is no longer an error. Any errors will be displayed in the bottom right
corner.

### Options
There are several options for configuring the plugin:

- **Resolution**: The number of buckets (or bars) into which results will be
  distributed.
- **Budget**: Amount of time, per frame, that should be dedicated to sampling,
  in microseconds.
- **Updates**: The number of times the graph should be updated, per second.

# Permissions
Probably requires **no** permissions to operate.

# Building
If cloning the repository, ensure that submodules are downloaded:

```bash
git clone --recurse-submodules https://github.com/Anaminus/probably
```

Otherwise, ensure that submodules are up to date:

```bash
git submodule update --init --recursive
```

This project is built with [Rojo][rojo]. Run the `build` command, outputting to
your configured plugins directory:

```bash
rojo build --output $PLUGINS_PATH
```

# License
The source code and assets for Probably, except for the logo, are licensed under
[MIT](LICENSE).

[rojo]: https://rojo.space/

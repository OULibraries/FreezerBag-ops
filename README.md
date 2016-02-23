# FreezerBag-ops
Shell scripts for rsyncing bags and executing freezerbag.py utility.

## Dependency
* FreezerBag
https://github.com/OULibraries/FreezerBag

## Usage
Each of these scripts takes arguments. They all expect to be pointed at flat directories full of unzipped/tarred bags.

### bag_conflicts
Checks for name collisions in two directories. Emails any collisions.

```
bag_conflicts.sh bagdir1 bagdir2 email@example.com ccemail@example.com
```

### bag_rsync
Syncs valid bags from one dir to another. Emails per-bag results.

```
bag_rsync.sh srcbagdir destbagdir/ email@example.com ccemail@example.com
```

### Pushes bags to aws glacier.  Emails per-bag results.
```
bag_freeze.sh srcbagdir destglaciervault email@example.com ccemail@example.com
```

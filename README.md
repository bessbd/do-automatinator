# Digitalocean Automatinator
## The Backstory
* Digitalocean offers cheap VPS service
* You only have to pay for the hours your machines "exist", so you can go even cheaper if you are not running (permanent) services, but using the machines for development, etc.
* You don't have to pay when the machines are "destroyed"
* You can save the machines
* You can only save machines that are powered-off

## The Itch
* You can't "just" shutdown, snapshot and destroy a machine with a single click of a button or a command

## The Scratch
do-automatinator is a command-line tool to shut down, snapshot and destroy a machine at Digitalocean. (And to do the reverse, too)

## Enough With The Texts Already, aka The Cheatsheet
### Setting Your Token
```bash
coffee app.coffee settoken <your digitalocean token>
```
(You only have to do this once)
### Shutting Down, Snapshotting and Destroying a Machine
```bash
coffee app.coffee save <machine name>
```
### Creating a Machine from a Snapshot (aka Restoring a Machine)
```bash
coffee app.coffee restore <machine name>
```

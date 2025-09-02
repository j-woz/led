
# LED TCL

proc abort { args } {
  puts "led: [ join {*}$args ]"
  exit 1
}

proc assert { condition msg } {
  if { ! [ uplevel 1 "expr $condition" ] } {
    error $msg
  }
}

# Given: enum E { T1 T2 }
# Defines global array E with members E(T1)=0, E(T2)=1
proc enum { name members } {
  uplevel #0 "global $name"
  global $name
  set n 0
  foreach m $members {
    set ${name}($m) $n
    incr n
  }
}

# Ternary operator
proc ? { condition a b } {
  if [ uplevel expr $condition ] {
    return $a
  } else {
    return $b
  }
}

proc cat { args } {
  return [ join $args " " ]
}

proc printf { args } {
  set newline ""
  if { [ lindex $args 0 ] == "-n" } {
    set newline "-nonewline"
    head args
  }
  if { [ llength $args ] == 0 } {
    error "printf: Requires format!"
  }
  set fmt [ lindex [ head args ] 0 ]
  puts {*}$newline [ format $fmt {*}$args ]
}

# usage: head <list> <count>?
# Reordered arguments 2023-10-25
# @return and remove first element of list
proc head { args } {
  switch [ llength $args ] {
    1 {
      set name [ lindex $args 0 ]
      set count 1
    }
    2 {
      set name  [ lindex $args 0 ]
      set count [ lindex $args 1 ]
    }
    default {
      error "head: requires: <list> <count>? - received: $args"
    }
  }

  upvar $name L

  set result [ list ]
  for { set i 0 } { $i < $count } { incr i } {
    lappend result [ lindex $L 0 ]
    set L [ lreplace $L 0 0 ]
  }
  return $result
}

# Random integer in [x1,x2]
proc rand_int { x1 x2 } {
  if { $x1 > $x2 } {
    error "bad boundaries!"
  }
  set range [ expr $x2 - $x1 + 1 ]
  set r [ expr int(rand() * $range) ]
  set result [ expr $x1 + $r ]
  return $result
}

proc ensure_file_exists { path } {
  if [ file exists $path ] {
    return true
  }
  try {
    set d [ file dirname $path ]
    file mkdir $d
    set fd [ open $path "w" ]
    close $fd
  } on error e {
    puts $e
    return false
  }
  return true
}

# Math mode
proc (( { args } {
  if { [ lindex $args end ] ne "))" } {
    abort "error in (( - no matching ))"
  }

  if { [ lindex $args 1 ] eq "=" } {
    set lvalue [ lindex $args 0 ]
    upvar $lvalue target
    set tokens [ lreplace $args 0 1 ]
    set tokens [ lreplace $tokens end end ]
    set target [ expr {*}$tokens ]
    return $target
  } else {
    return [ expr {*}$args ]
  }
}

# Debugging variable query
# Note: Not fast due to "info exists"
# Use "- <MSG>" for a message
# Use "." for a blank line
# TODO: Single line mode?
proc show { args } {
  set N [ llength $args ]
  set quote false
  for { set i 0 } { $i < $N } { incr i } {
    set v [ lindex $args $i ]

    if { $v eq "-" } {
      incr i
      set msg [ lindex $args $i ]
      puts -nonewline $msg
      puts -nonewline " "
      continue
    }

    if { $v eq "-q" } {
      set quote true
      continue
    }

    if { $v eq "." } {
      puts ""
      continue
    }

    upvar $v t
    if { ! [ info exists t ] } {
      error "show: Variable does not exist: $v"
    }
    if { $quote } {
      puts "$v: '$t'"
    } else {
      puts "$v: $t"
    }
  }
}

# Assign argv to given names
# A: Associative-array: map option to value
# P: Positional parameters: indexed from 0
# opts: Options string e.g., "hc:p"
# V: e.g., $argv
proc getopts { A_name P_name opts V } {
  upvar $A_name A
  upvar $P_name P
  upvar optind count
  # Colons
  array set C {}
  _getopts_parse_opt_string C $opts
  set i 0
  set count 0
  set q 0
  set N [ llength $V ]
  set dash_found false
  while { $i < $N } {
    set t [ lindex $V $i ]
    set c [ string range $t 0 0 ]
    if { $c eq "-" && ! $dash_found} {
      set c [ string range $t 1 1 ]
    } else {
      set P($q) $t
      incr q
      incr i
      continue
    }
    if { $c eq "-" } { # Found --
      set dash_found true
      incr i
      incr count
      continue
    }
    if { ! [ info exists C($c) ] } {
      error "getopts: invalid flag: $c"
    }
    if { [ string equal $C($c) ":" ] } {
      incr i
      incr count
      set t [ lindex $V $i ]
      lappend A($c) $t
    } else {
      lappend A($c) {}
    }
    incr i
    incr count
  }
}

proc _getopts_parse_opt_string { C_name opts } {
  upvar $C_name C
  set i 0
  set N [ string length $opts ]
  while { $i < $N } {
    set c     [ string range $opts $i $i ]
    incr i
    set colon [ string range $opts $i $i ]
    if { [ string equal $colon ":" ] } {
      set C($c) ":"
      incr i
    } else {
      set C($c) "_"
    }
  }
}

# Last character of string
proc lastc { s } {
  return [ string range $s end end ]
}

namespace eval led {

  ## Core variables
  # A list
  # When indexing into here, must convert cln to 0-based
  variable text
  variable file_current
  # Current Line Number (1-based)
  # If this is 0, then the file is empty
  variable cln
  variable modified

  ## Features
  variable cut_buffer
  variable search_last

  ## Settings
  # Number of context lines
  variable context_print
  variable context_edit
  variable verbosity
  variable sysdir

  namespace export verbose a i

  proc init { args } {
    global env
    global VERBOSE

    variable cln
    variable modified
    variable context_edit
    variable context_print
    variable cut_buffer
    variable marks
    variable text
    variable verbosity
    variable sysdir
    variable search_last

    load $env(LED_HOME)/lib/libtcleditor.$env(SO_SUFFIX)
    set sysdir $env(HOME)/.sys/led

    set context_print 5
    set context_edit 1

    enum VERBOSE { fatal warning info debug trace }
    set verbosity $VERBOSE(warning)

    # Blank file, no lines, unmodified
    set cln 0
    set text {}
    set modified false

    set search_last ""

    setup_histories
    initialize $sysdir

    set cut_buffer ""
    set marks [ dict create ]

    getopts A P "hqv" $args
    if [ info exists A(h) ] {
      led_help
    }
    set_verbosity A
    setup_file P
  }

  proc setup_histories { } {
    variable sysdir
    ensure_file_exists $sysdir/edit.history
    ensure_file_exists $sysdir/command.history
    ensure_file_exists $sysdir/file.history
  }

  proc set_verbosity { A* } {
    global VERBOSE
    upvar ${A*} A
    set led::verbosity $VERBOSE(info)
    if [ info exists A(v) ] {
      switch [ llength $A(v) ] {
        1 {
          set led::verbosity $VERBOSE(debug)
          led::verbose debug "logging at debug"
        }
        2 {
          set led::verbosity $VERBOSE(trace)
          led::verbose debug "logging at trace"
        }
      }
    }
    if [ info exists A(q) ] {
      set led::verbosity $VERBOSE(warning)
    }
  }

  # P: The positional command line arguments (list)
  proc setup_file { P* } {
    upvar ${P*} P

    set led::file_current ""

    if { [ array size P ] >= 3 } {
      abort "too many arguments!"
    }

    if { [ array size P ] >= 1 } {
      set led::file_current $P(0)
    }

    if { $led::file_current ne "" } {
      led::led_open
    }

    # Second argument
    if { [ array size P ] == 2 } {
      if [ string is integer $P(1) ] {
        goto $P(1)
        print "n"
      } elseif { [ string range $P(1) 0 0 ] eq "/" } {
        setup_search $P(1)
      } else {
        abort "unusable 2nd argument: '$P(1)'"
      }
    }
  }

  proc led_open { } {
    variable cln
    variable file_current
    variable text
    set text [ list ]
    if { $file_current eq "" } return
    if { ! [ file exists $file_current ] } {
      verbose info "new file: $file_current"
      return
    }
    set fd [ open $file_current ]
    verbose info "opened: $file_current"
    # This is 0 unless the file has content
    set cln 0
    while { [ gets $fd line ] >= 0 } {
      lappend text $line
    }
    if { [ llength $text ] > 0 } {
      set cln 1
    }
    close $fd
  }

  proc setup_search { text } {
    set led::cln 0
    set found [ search $text ]
    if { ! $found } {
      set led::cln 1
    }
  }

  proc run { } {
    variable cln
    while { true } {
      read_cmd ": "
      set command [ get_last_result ]
      handle $command
    }
  }

  proc handle { input } {
    variable cln

    set address [ parse_address input ]
    # show address

    # TODO: s///

    switch -regexp $input {
      "^\\." { edit }
      "^_"   { do_eval {*}$input }
      "^a"   { led_append }
      "^c"   { change }
      "^d"   { delete $address }
      "^h"   { help }
      "^i"   { insert }
      "^[eE].*" { edit_current_file $input }
      "^[fF].*" { select_current_file $input }
      "^[kK].*" { mark $input $address }
      "^n.*" { print $input }
      "^p.*" { print $input }
      "^[qQ].*" { quit  $input }
      "^r.*" { read_current_file $input $address }
      "^R"   { reload_current_file $input $address }
      "^s.*" { substitute $input $address }
      "^t.*" { transfer $input }
      "^[wW].*" { write $input }
      "^x"   { paste $input $address }
      "^[yY].*" { yank $input $address }
      "^/.*" { search $input }
      "^\\\\.*" { search $input }
      "^="   { status $input $address}
      "^!.*"  { shell $input }
      "'.*" { try_goto_mark $input }
      default {
        if { $input eq "" } {
          try_goto $address
        } else {
          verbose warning "illegal command: $input"
        }
      }
    }
  }

  proc peekc { s } {
    # Return first character
    return [ string range $s 0 0 ]
  }

  proc getc { s* } {
    # Remove and return first character
    upvar ${s*} s
    set c [ string range $s 0 0 ]
    set s [ string range $s 1 end ]
    return $c
  }

  proc consume_int { inputs* } {
    upvar ${inputs*} inputs
    set digits [ list ]
    while true {
      set c [ peekc $inputs ]
      if { [ string is integer -strict $c ] || \
               $c eq "-" } {
        set c [ getc inputs ]
        lappend digits $c
      } else break
    }
    if { $digits == "-" } {
      # TODO: Throw exception
      verbose warning "bad address: '$digits'"
      return "ERROR"
    }
    return [ join $digits "" ]
  }

  proc consume_comma { inputs* } {
    upvar ${inputs*} inputs
    if { [ peekc $inputs ] == "," } {
      return [ getc inputs ]
    }
    return ""
  }

  proc parse_address { inputs* } {
    upvar ${inputs*} inputs
    set a0 [ consume_int   inputs ]
    if { $a0 eq "ERROR" } return
    set c  [ consume_comma inputs ]
    set a1 [ consume_int   inputs ]
    if { $a0 eq "ERROR" } return
    # show a0 a1
    return [ list $a0 $c $a1 ]
  }

  proc edit { } {
    variable cln
    variable file_current
    variable modified
    variable text

    if { $cln == 0 } {
      puts "(file is blank)"
      return
    }

    set modified true

    set prompt [ format "%4i> " $cln ]
    if [ read_edit $prompt [ get_text $cln ] ] {
      set new [ get_last_result ]
      # foreach t $text { show t }
      set text [ lset text [ expr $cln - 1 ] $new ]
      # foreach t $text { show t }
    } else {
      puts info "read error"
    }
  }

  proc led_append { } {
    variable cln
    variable text
    set text [ linsert $text $cln "" ]
    incr cln
    edit
  }

  proc insert { } {
    variable cln
    variable text
    if { [ llength $text ] == 0 } {
      set cln 1
    }
    set text [ linsert $text [ expr $cln - 1 ] "" ]
    edit
  }

  proc a { s } {
    # For use from _ macros

    variable cln
    variable text

    set text [ linsert $text $cln $s ]
    incr cln
    return ""
  }

  proc i { s } {
    # For use from _ macros

    variable cln
    variable text

    if { [ llength $text ] == 0 } {
      set cln 1
    }
    set text [ linsert $text [ expr $cln - 1 ] $s ]
    return ""
  }

  proc change { } {
    edit
  }

  proc delete { address } {
    variable cln
    variable modified
    variable text
    address_normalize address
    address_delete $address
    set n [ llength $text ]
    if { $cln > $n } {
      set cln $n
    }
    set modified true
  }

  proc address_delete { address } {
    variable cln
    variable cut_buffer
    variable text
    set p0 [ lindex $address 0 ]
    set p1 [ lindex $address 2 ]
    set result [ list ]
    for { set i $p0 } { $i <= $p1 } { incr i } {
      led::verbose info "delete: $i"
      set t [ get_text $p0 ]
      lappend result $t
      set text [ lreplace $text [ expr $p0 - 1 ] [ expr $p0 - 1 ] ]
      # update_marks $p0 -1
      # show i t
    }
    set cut_buffer $result
  }

  proc do_eval { args } {
    global VERBOSE
    variable context_edit
    variable context_print
    variable verbosity
    set command [ lreplace $args 0 0 ]
    verbose debug "command: $command"
    try {
      set result [ uplevel #0 {*}$command ]
    } on error e {
      puts "Tcl error!"
      set result $e
    }
    if { $result ne "" } { puts $result }
  }

  proc try_goto { address } {
    set n [ lindex $address 0 ]
    if { [ string length $n ] == 0 } {
      verbose debug "noop"
      return
    }
    goto $n
  }

  proc goto { line_number } {
    variable cln
    variable text
    if { $line_number < 0 } {
      (( line_number = [ llength $text ] + $line_number + 1 ))
    }
    if { $line_number < 1 } {
      puts "error $line_number"
      set msg [ cat "invalid line number:" \
                    "$line_number (line count: $n)" ]
      verbose warning $msg
      return
    }
    set n [ llength $text ]
    if { $line_number > $n } {
      verbose info "goto: $line_number: end-of-file: line $n"
      set line_number $n
    } else {
      verbose "goto: $line_number"
    }
    set cln $line_number
  }

  proc try_goto_mark { input } {
    variable marks
    # Pop the apostrophe
    getc input
    if { $input in [ dict keys $marks ] } {
      goto [ dict get $marks $input ]
    } else {
      verbose warning "mark not found: $input"
    }
  }

  proc get_text { i } {
    # Get text at line i
    variable text
    incr i -1
    return [ lindex $text $i ]
  }

  proc set_text { i s } {
    # Set text at line i to s
    variable text
    incr i -1
    lset text $i $s
  }

  proc print { command } {
    variable cln
    variable context_print
    variable text
    set numbering [ ? [ string equal $command "n" ] 1 0 ]
    set n [ llength $text ]
    # show cln n text
    set i0 [ expr $cln - $context_print ]
    set i1 [ expr $cln + $context_print ]
    for { set i $i0 } { $i <= $i1 } { incr i } {
      if { $i > 0 && $i <= $n } {
        print_line $numbering [ expr $cln == $i ] $i
      }
    }
  }

  proc print_line { numbering is_cln i } {
    if $numbering {
      set symbol [ ? $is_cln "@" ":" ]
      printf "%4i%s %s" $i $symbol [ get_text $i ]
    } else {
      printf "%s" [ get_text $i ]
    }
  }

  proc edit_current_file { command } {

    variable file_current
    variable modified

    if { [ lastc $command ] eq "." } {
      lappend command "."
    }

    switch [ llength $command ] {
      1 {
        if { $file_current eq "" } {
          puts "(no current file)"
        } else {
          puts $file_current
        }
      }
      2 {
        if { [ peekc $command ] eq "E" } {
          set modified false
        }
        if $modified {
          puts "There are unsaved changes."
          return
        }
        set file2 [ lindex $command 1 ]
        if { $file2 eq "." } {
          set file2 [ get_file ]
        }
        set file_current $file2
      }
      default {
        verbose warning "bad e command: $command"
      }
    }
    led_open
  }

  proc select_current_file { command } {

    variable file_current
    variable modified

    if { [ lastc [ lindex $command 0 ] ] eq "." } {
      lappend command "."
    }

    switch [ llength $command ] {
      1 {
        if { $file_current eq "" } {
          puts "(no current file)"
        } else {
          puts $file_current
        }
      }
      2 {
        set file2 [ lindex $command 1 ]
        if { $file2 eq "." } {
          set file2 [ get_file ]
        }
        if { [ file exists $file2 ] } {
          if { [ peekc [ lindex $command 0 ] ] eq "F" } {
            verbose info "overwriting: $file2"
          } else {
            puts "file exists: $file2"
            return
          }
        }

        set file_current $file2
      }
      default {
        verbose warning "bad f command: $command"
      }
    }
  }

  proc read_current_file { command address } {
    variable cln
    variable file_current
    variable modified
    variable text

    if { [ lastc $command ] eq "." } {
      lappend command "."
    }

    # Current file after this command
    set file1 $file_current
    switch [ llength $command ] {
      1 {
        if { $file_current eq "" } {
          puts "current file is unset!"
          return
        }
        set file2 $file_current
      }
      2 {
        set file2 [ lindex $command 1 ]
        if { $file2 eq "." } {
          set file2 [ get_file ]
        }
      }
    }

    try {
      set fd [ open $file2 "r" ]
    } on error e {
      puts "could not read: $file2"
      return
    }

    # To detect modification
    set cln_orig $cln

    set line_number [ lindex $address 0 ]
    if { $line_number ne "" } {
      set cln $line_number
    }
    incr cln 1

    while { [ gets $fd line ] >= 0 } {
      set text [ linsert $text [ expr $cln - 1 ] $line ]
      incr cln 1
    }
    close $fd

    if { $file1 eq "" } {
      set file_current $file2
      verbose info "working file: $file_current"
    }

    if { $cln_orig != $cln } {
      set modified true
    }
  }

  proc substitute { input address } {
    variable substitution_last

    address_normalize address

    set s [ getc input ]
    assert [ string equal $s "s" ] "Broken substitute"
    if { [ string length $input ] == 0 } {
      set tokens $substitution_last
    } else {
      set delimiter [ getc input ]
      set tokens [ split $input $delimiter ]
      set substitution_last $tokens
    }
    lassign $tokens pattern replacement options

    set p0 [ lindex $address 0 ]
    set p1 [ lindex $address 2 ]

    for { set i $p0 } { $i <= $p1 } { incr i } {
      set t0 [ get_text $i ]
      set t1 [ regsub $pattern $t0 $replacement ]
      set_text $i $t1
    }
  }
  proc get_file { } {
    global env
    # Use Tcl pwd as env(PWD) may be out-of-date
    read_file "[pwd] > "
    set file_current [ get_last_result ]
    puts "file: $file_current"
  }

  proc mark { command address } {
    variable cln
    variable marks
    if { $command eq "K" } {
      show_marks
      return
    }
    # This is k|K:
    getc command
    set c [ getc command ]
    if { $c != "-" } {
      set mark $c
    } else {
      set mark [ getc command ]
      dict unset marks $mark
      return
    }

    if { [ string length [ lindex $address 1 ] ] > 0 ||
         [ string length [ lindex $address 2 ] ] > 0 } {
      puts "address must be a single line!"
      return
    }
    set line_number [ lindex $address 0 ]
    if { $line_number eq "" } {
      set line_number $cln
    }
    dict set marks $mark $line_number
  }

  proc show_marks { } {
    variable marks
    if { [ dict size $marks ] == 0 } {
      verbose "(no marks)"
      return
    }
    dict for { k v } $marks {
      puts "\[$k\] $v: [get_text $v]"
    }
  }

  proc write { command } {
    variable file_current
    variable modified
    variable text

    switch [ llength $command ] {
      1 {
        set file1 $file_current
        set file2 $file_current
      }
      2 {
        set file1 $file_current
        set file2 [ lindex $command 1 ]
        if { [ file exists $file2 ] } {
          # Must select with 'f/F' to overwrite
          puts "file exists: $file2"
          return
        }
      }
      default {
        puts "bad w command: $command"
        return
      }
    }
    set file_current $file2

    if { $file_current eq "" } {
      puts "no current file!"
      return
    }

    make_backups $file_current

    try {
      set fd [ open $file_current "w" ]
    } on error e {
      puts "could not write: $file_current"
      set file_current $file1
      return
    }

    set n [ llength $text ]
    for { set i 0 } { $i < $n } { incr i } {
      puts $fd [ lindex $text $i ]
    }
    close $fd
    verbose info "wrote:  $file_current"
    set modified false
    if { $command eq "wq" } {
      quit
    }
  }

  proc make_backups { file_current } {
    if { ! [ file exists $file_current ] } {
      verbose info "backup: current file does not yet exist..."
      return
    }
    set file_backup ${file_current}~
    if { [ file exists $file_backup ] } {
      set backup_time [ file mtime $file_backup ]
      set now [ clock seconds ]
      set age [ expr $now - $backup_time ]
      # show age
      if { $age < 60 } return
    }
    verbose info "backup: $file_backup"
    file copy -force $file_current $file_backup
    if { [ rand_int 0 1 ] == 0 } return
    if [ file exists ${file_current}_~1~ ] {
      recurse_backup $file_current 1
    }
    verbose info "backup: ${file_current}_~1~"
    file copy -force $file_backup ${file_current}_~1~
  }

  proc recurse_backup { file_current this_index } {
    if { [ rand_int 0 1 ] == 0 } return
    set next_index [ expr $this_index + 1 ]
    set this_backup ${file_current}_~${this_index}~
    set next_backup ${file_current}_~${next_index}~
    if { [ file exists $next_backup ] } {
      recurse_backup $file_current $next_index
    }
    verbose info "backup: $next_backup"
    # Preserve timestamps for older files
    file rename -force $this_backup $next_backup
  }

  proc paste { command address } {
    variable text
    variable cln
    variable cut_buffer
    variable modified
    address_normalize address
    if { [ llength $cut_buffer ] != 0 } {
      set modified true
    }
    foreach t $cut_buffer {
      incr cln
      set text [ linsert $text [ expr $cln - 1 ] $t ]
    }
  }

  proc yank { command address } {
    variable cut_buffer
    variable cln

    if { $command eq "Y" } {
      foreach t $cut_buffer {
        puts $t
      }
      return
    }

    set cut_buffer [ address_copy $address ]
    show cut_buffer
  }

  proc address_copy { address } {
    address_normalize address
    set result [ list ]
    set p0 [ lindex $address 0 ]
    set p1 [ lindex $address 2 ]
    set result [ list ]
    for { set i $p0 } { $i <= $p1 } { incr i } {
      set t [ get_text $i ]
      # show i t
      lappend result $t
    }
    return $result
  }

  proc address_normalize { address* } {
    # Fill in any blanks in the address
    variable cln
    variable text
    upvar ${address*} address
    set has_comma false
    if { [ string length [ lindex $address 1 ] ] != 0 } {
      set has_comma true
    }
    # show address has_comma
    if { [ string length [ join $address "" ] ] == 0 } {
      set address [ list $cln , $cln ]
      return
    }
    if $has_comma {
      if { [ string length [ lindex $address 0 ] ] == 0 } {
        lset address 0 1
      }
      if { [ string length [ lindex $address 2 ] ] == 0 } {
        lset address 2 [ llength $text ]
      }
    } else {
      if { [ string length [ lindex $address 0 ] ] == 0 } {
        lset address 0 [ lindex $address 2 ]
      } elseif { [ string length [ lindex $address 2 ] ] == 0 } {
        lset address 2 [ lindex $address 0 ]
      }
    }
    lset address 1 ","
    # show address
  }

  proc verbose { args } {
    global VERBOSE
    variable verbosity

    set n [ llength $args ]
    switch $n {
      1 { verbose info {*}$args }
      2 {
        lassign $args level message
        if { $VERBOSE($level) <= $verbosity } {
          puts "$message"
        }
      }
      default {
        abort "verbose: ERROR: given $n args: $args"
      }
    }
  }

  proc search { command } {
    variable cln
    variable search_last
    variable text
    set result false
    # Either forward or back slash
    set slash [ getc command ]
    # Offset so as not to match current line
    set d [ ? [ string equal $slash "/" ] 1 -1 ]
    set pattern $command
    # Slash with no argument reuses last search
    if { $pattern eq "" } {
      set pattern $search_last
    } else {
      set search_last $pattern
    }
    if { $pattern eq "" } {
      puts "no pattern"
      return false
    }
    set line [ expr $cln + $d ]
    set max  [ llength $text ]
    while { true } {
      if { $line == 0 || $line > $max } {
        puts "not found"
        break
      }
      if [ regexp $pattern [ get_text $line ] ] {
        set cln $line
        print "n"
        break
        set result true
      }
      incr line $d
    }
    return $result
  }

  proc status { command address } {
    variable cln
    variable file_current
    variable modified
    variable text
    variable search_last

    set m [ ? $modified " (modified)" "" ]
    set n [ llength $text ]
    set s [ ? [ string equal $search_last "" ] \
                "" " /$search_last" ]
    puts "$cln/$n $file_current$m$s"
  }

  # TODO: Handle non-zero exit codes
  proc shell { command } {
    global env
    set c [ getc command ]
    assert [ string equal $c "!" ] "error in shell{}"
    trim command
    if { [ string length $command ] == 0 } {
      exec $env(SHELL)
    } else {
      exec $command > /dev/stdout
    }
  }

  proc quit { args } {
    variable modified
    if $modified {
      if { [ lindex $args 0 ] ne "Q" } {
        puts "There are unsaved changes."
        return
      }
    }

    finalize
    exit 0
  }

  proc help { } {
    # Help from within the program
    global env
    puts "LED_HOME: $env(LED_HOME)"
    puts ""
    puts [ exec cat $env(LED_HOME)/etc/help.txt ]
  }

  proc led_help { } {
    # Help from the command line
    help
    exit
  }
}

namespace import led::a led::i

if [ info exists env(LED_RUN) ] {
  # Run this as the main program
  led::init {*}$argv
  led::run
}

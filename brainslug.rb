#!/usr/bin/env ruby

require 'gtk3'

class BrainSlug
  LAUNCH_SERVICE_TEXT = 'Launch PS3 gamepad service'
  RESET_BLUETOOTH_TEXT = 'Restore Bluetooth'
  def initialize()
    builder = Gtk::Builder.new
    builder.add_from_file('brainslug.glade')
    builder.connect_signals {|handler| method(handler) }
    @ps3Service = -1
    @progressbar = builder['progressbar']
    @progressbar.text = ''
    @serviceButton = builder['serviceButton']
    @serviceButton.label = LAUNCH_SERVICE_TEXT
    @pairButton = builder['pairButton']
    @window = builder['applicationwindow1']
    @window.show_all()
    checkPermissions()
  end # initialize

  def checkPermissions()
    if(0 != Process.euid)
      @serviceButton.sensitive = @pairButton.sensitive = false
      @progressbar.text = 'Root permissions required! Relaunch with [gk]sudo!'
    end
  end # checkPermissions

  def restoreSixad
    @progressbar.text = 'Enabling Bluetooth'
    system('sixad -restore')
    GLib::Timeout.add_seconds(3){ yield }
  end # restoreSixad

  def enableHCI0
    @progressbar.text = 'Bringing up first Bluetooth device'
    system('hciconfig hci0 up')
    GLib::Timeout.add_seconds(3) { yield }
  end # enableHCI0

  def launchPS3Service
    @progressbar.fraction = 0
    restoreSixad() {
      @progressbar.fraction += 0.33
      enableHCI0() {
        @progressbar.fraction += 0.33
        @progressbar.text = 'Running PS3 gamepad service'
        @ps3Service = spawn('sixad -start', :pgroup => true)
        if(0 <= @ps3Service)
          GLib::Timeout.add_seconds(3) {
            @progressbar.fraction = 1
            @progressbar.text = 'Press the PS button to connect paired gamepads!'
            @serviceButton.label = RESET_BLUETOOTH_TEXT
            @serviceButton.sensitive = true
            false # Don't repeat
          }
        else
          @progressbar.fraction = 0
          @serviceButton.sensitive = true
        end
        false # Don't repeat
      }
      false # Don't repeat
    }
  end # launchPS3Service

  def killPS3Service
    if(0 <= @ps3Service)
      Process.kill('TERM', -Process.getpgid(@ps3Service))
      puts("Waiting for process #{@ps3Service}")
      Process.waitpid(@ps3Service)
      @ps3Service = -1
    end
  end # killPS3Service

  def restoreBluetooth
    @progressbar.fraction = 0
    killPS3Service()
    restoreSixad() {
      @progressbar.fraction = 0.5
      enableHCI0() {
        @progressbar.fraction = 1
        @progressbar.text = ''
        @serviceButton.label = LAUNCH_SERVICE_TEXT
        @serviceButton.sensitive = true
        # For that flash of 'progress completed' before resetting
        GLib::Timeout.add (100){ @progressbar.fraction = 0; false }
        false # Don't repeat
      }
      false # Don't repeat
    }
  end # restoreBluetooth

  # Gtk callbacks

  def serviceButtonClicked
    if(LAUNCH_SERVICE_TEXT == @serviceButton.label)
      @serviceButton.sensitive = false
      launchPS3Service()
    else
      @serviceButton.sensitive = false
      restoreBluetooth()
    end
  end # serviceButtonClicked

  def pairButtonClicked
    IO.popen('sixpair') { |io|
      @progressbar.text = io.read().strip()
      Process.waitpid(io.pid)
    }
  end # pairButtonClicked

  def quit()
    killPS3Service()
    Gtk::main_quit()
  end # quit
end

if(__FILE__ == $0)
  brainslug = BrainSlug.new()
  Gtk.main()
end

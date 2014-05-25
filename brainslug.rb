#!/usr/bin/env ruby

require 'gtk3'

# Gtk UI for managing PS3 gamepads
class BrainSlug
  def initialize()
    builder = Gtk::Builder.new
    #builder.add_from_file('brainslug.glade')
    builder.add_from_string(UI_DEFINITION)
    builder.connect_signals {|handler| method(handler) }
    @ps3Service = -1
    @progressbar = builder['progressbar']
    @progressbar.text = ''
    @bluetoothButton = builder['bluetoothButton']
    @serviceButton = builder['serviceButton']
    @pairButton = builder['pairButton']
    @window = builder['applicationwindow1']
    @window.show_all()
    checkPermissions()
  end # initialize

  # Ensure that we have root permissions
  # Otherwise, make the UI unreponsive
  def checkPermissions()
    if(0 != Process.euid)
      @bluetoothButton.sensitive = @serviceButton.sensitive = @pairButton.sensitive = false
      @progressbar.text = 'Root permissions required! Relaunch with [gk]sudo!'
    end
  end # checkPermissions

  # Restores Bluetooth connectivity via sixad
  # Gives 3 seconds for operation to complete, then yields
  def restoreSixad()
    @progressbar.text = 'Enabling Bluetooth'
    system('sixad -restore')
    GLib::Timeout.add_seconds(3){ yield }
  end # restoreSixad

  # Enables the first Bluetooth device
  # Gives 3 seconds for operation to complete, then yields
  def enableHCI0()
    @progressbar.text = 'Bringing up first Bluetooth device'
    system('hciconfig hci0 up')
    GLib::Timeout.add_seconds(3) { yield }
  end # enableHCI0

  # Launches the PS3 gamepad connection service
  def launchPS3Service()
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
            @bluetoothButton.sensitive = true
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

  # Kills the PS3 gamepad connection service, if running
  def killPS3Service()
    if(0 <= @ps3Service)
      Process.kill('TERM', -Process.getpgid(@ps3Service))
      puts("Waiting for process #{@ps3Service}")
      Process.waitpid(@ps3Service)
      @ps3Service = -1
    end
  end # killPS3Service

  # Restores standard Bluetooth connectivity
  def restoreBluetooth()
    @progressbar.fraction = 0
    killPS3Service()
    restoreSixad() {
      @progressbar.fraction = 0.5
      enableHCI0() {
        @progressbar.fraction = 1
        @progressbar.text = ''
        @serviceButton.sensitive = true
        @bluetoothButton.sensitive = true
        # For that flash of 'progress completed' before resetting
        GLib::Timeout.add (100){ @progressbar.fraction = 0; false }
        false # Don't repeat
      }
      false # Don't repeat
    }
  end # restoreBluetooth

  # Gtk callbacks

  def serviceButtonClicked()
    @serviceButton.sensitive = false
    @bluetoothButton.sensitive = false
    launchPS3Service()
  end # serviceButtonClicked

  def bluetoothButtonClicked()
    @serviceButton.sensitive = false
    @bluetoothButton.sensitive = false
    restoreBluetooth()
  end

  def pairButtonClicked()
    IO.popen('sixpair') { |io|
      @progressbar.text = io.read().strip()
      Process.waitpid(io.pid)
    }
  end # pairButtonClicked

  def quit()
    killPS3Service()
    Gtk::main_quit()
  end # quit

  # Dumped final GtkBuilder definition here,
  # so that we don't have to chase a .glade file around
  UI_DEFINITION = '<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated with glade 3.16.1 -->
<interface>
  <requires lib="gtk+" version="3.10"/>
  <object class="GtkImage" id="image1">
    <property name="visible">True</property>
    <property name="can_focus">False</property>
    <property name="icon_name">bluetooth</property>
    <property name="use_fallback">True</property>
  </object>
  <object class="GtkImage" id="image2">
    <property name="visible">True</property>
    <property name="can_focus">False</property>
    <property name="icon_name">brainslug</property>
    <property name="use_fallback">True</property>
  </object>
  <object class="GtkImage" id="image3">
    <property name="visible">True</property>
    <property name="can_focus">False</property>
    <property name="icon_name">brainslug</property>
    <property name="use_fallback">True</property>
  </object>
  <object class="GtkApplicationWindow" id="applicationwindow1">
    <property name="can_focus">False</property>
    <property name="title" translatable="yes">Manage PS3 gamepads</property>
    <property name="window_position">center</property>
    <property name="show_menubar">False</property>
    <signal name="delete-event" handler="quit" swapped="no"/>
    <child>
      <object class="GtkBox" id="box1">
        <property name="visible">True</property>
        <property name="can_focus">False</property>
        <property name="orientation">vertical</property>
        <property name="spacing">5</property>
        <child>
          <object class="GtkBox" id="box2">
            <property name="visible">True</property>
            <property name="can_focus">False</property>
            <property name="homogeneous">True</property>
            <child>
              <object class="GtkButton" id="bluetoothButton">
                <property name="label" translatable="yes">Restore Bluetooth</property>
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="image">image1</property>
                <property name="image_position">top</property>
                <property name="always_show_image">True</property>
                <signal name="clicked" handler="bluetoothButtonClicked" swapped="no"/>
              </object>
              <packing>
                <property name="expand">False</property>
                <property name="fill">True</property>
                <property name="position">0</property>
              </packing>
            </child>
            <child>
              <object class="GtkButton" id="serviceButton">
                <property name="label" translatable="yes">Launch PS3 gamepad service</property>
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="image">image2</property>
                <property name="image_position">top</property>
                <property name="always_show_image">True</property>
                <signal name="clicked" handler="serviceButtonClicked" swapped="no"/>
              </object>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">1</property>
              </packing>
            </child>
            <child>
              <object class="GtkButton" id="pairButton">
                <property name="label" translatable="yes">Pair connected PS3 gamepads</property>
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="image">image3</property>
                <property name="image_position">top</property>
                <property name="always_show_image">True</property>
                <signal name="clicked" handler="pairButtonClicked" swapped="no"/>
              </object>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">2</property>
              </packing>
            </child>
          </object>
          <packing>
            <property name="expand">True</property>
            <property name="fill">True</property>
            <property name="padding">2</property>
            <property name="position">0</property>
          </packing>
        </child>
        <child>
          <object class="GtkProgressBar" id="progressbar">
            <property name="visible">True</property>
            <property name="can_focus">False</property>
            <property name="show_text">True</property>
            <property name="ellipsize">end</property>
          </object>
          <packing>
            <property name="expand">False</property>
            <property name="fill">True</property>
            <property name="padding">2</property>
            <property name="position">1</property>
          </packing>
        </child>
      </object>
    </child>
  </object>
</interface>
'
end

if(__FILE__ == $0)
  brainslug = BrainSlug.new()
  Gtk.main()
end

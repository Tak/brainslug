#!/usr/bin/env ruby

require 'gtk3'

class BrainSlug
  LAUNCH_SERVICE_TEXT = 'Launch PS3 gamepad service'
  RESET_BLUETOOTH_TEXT = 'Restore normal Bluetooth connectivity'
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
  end

  def spawnInNewProcessGroup(command)
    pid = fork() {
      Process.setsid()
      exec(command)
    }
    return pid
  end

  def launchPS3Service
    @progressbar.fraction = 0
    @progressbar.text = 'Enabling Bluetooth'
    system('sixad -restore')
    GLib::Timeout.add(3000) {
      @progressbar.fraction += 0.33
      @progressbar.text = 'Bringing up first Bluetooth device'
      system('hciconfig hci0 up')
      GLib::Timeout.add(3000) {
        @progressbar.fraction += 0.33
        @progressbar.text = 'Running PS3 gamepad service'
        @ps3Service = spawnInNewProcessGroup('sixad -start')
        if(0 <= @ps3Service)
          GLib::Timeout.add(3000) {
            @progressbar.fraction = 1.0
            @serviceButton.label = RESET_BLUETOOTH_TEXT
            @serviceButton.sensitive = true
            false
          }
        else
          @progressbar.fraction = 0
          @serviceButton.sensitive = true
        end
        false
      }
      false
    }
  end

  def serviceButtonClicked
    if(LAUNCH_SERVICE_TEXT == @serviceButton.label)
      @serviceButton.sensitive = false
      launchPS3Service()
    else
      @serviceButton.label = LAUNCH_SERVICE_TEXT
    end
  end

  def pairButtonClicked
    puts("Pair button clicked!")
  end

	def quit()
    if(0 <= @ps3Service)
      Process.kill('TERM', -Process.getpgid(@ps3Service))
      puts("Waiting for process #{@ps3Service}")
      Process.waitpid(@ps3Service)
    end
		Gtk::main_quit()
	end # quit
end

if(__FILE__ == $0)
	brainslug = BrainSlug.new()
	Gtk.main()
end

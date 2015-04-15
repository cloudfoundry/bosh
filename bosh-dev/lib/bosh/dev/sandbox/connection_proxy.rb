require "socket"

module Bosh::Dev::Sandbox
  class ConnectionProxy

    def initialize(remote_host, remote_port, listen_port)
      @max_threads = 32
      @accept_thread
      @threads = []
      @server_sockets = {}
      @running = false
      @remote_host = remote_host
      @remote_port = remote_port
      @listen_port = listen_port
    end

    def start_background
      @accept_thread = Thread.new do
        start
      end
    end

    # This method is inspired by an example found at
    # http://blog.bitmelt.com/2010/01/transparent-tcp-proxy-in-ruby-jruby.html
    def start
      if @running
        raise "This ConnectionProxy is already running!"
      end
      @paused = false
      @running = true
      server = TCPServer.new(nil, @listen_port)
      while @running
        # Start a new thread for every client connection.
        begin
          sleep 0.1 while @paused

          socket = server.accept
          @threads << Thread.new(socket) do |client_socket|
            proxy_single_connection(client_socket)
          end
        rescue Interrupt => i
          server.close
        ensure
          # Clean up the dead threads, and wait until we have available threads.
          @threads = @threads.select { |t| t.alive? ? true : (t.join; false) }
          while @threads.size >= @max_threads
            puts "Too many ConnectionProxy threads in use! Sleeping until some exit."
            sleep 1
            @threads = @threads.select { |t| t.alive? ? true : (t.join; false) }
          end
        end
      end
    end

    def proxy_single_connection(client_socket)
      begin
        begin
          server_socket = TCPSocket.new(@remote_host, @remote_port)
          @server_sockets[Thread.current] = server_socket
        rescue Errno::ECONNREFUSED
          client_socket.close
          raise
        end

        while true
          sleep 0.1 while @paused

          # Wait for data to be available on either socket.
          (ready_sockets, dummy, dummy) = IO.select([client_socket, server_socket])
          begin
            ready_sockets.each do |socket|
              data = socket.readpartial(4096)
              if socket == client_socket
                # Read from client, write to server.
                server_socket.write data
                server_socket.flush
              else
                # Read from server, write to client.
                client_socket.write data
                client_socket.flush
              end
            end
          rescue EOFError
            break
          end
        end
      rescue StandardError => e
        # this happens when we get EOF on the client or server socket
      end
      @server_sockets.delete(Thread.current)
      server_socket.close rescue StandardError
      client_socket.close rescue StandardError
    end

    def pause
      @paused = true
    end

    def resume
      @paused = false
    end

    def stop
      if !@running
        raise "This ConnectionProxy is not running!"
      end
      @paused = false
      @running = false
      if @accept_thread
        @accept_thread.raise Interrupt
        @accept_thread.join
      end
      @server_sockets.each do |thread, socket|
        socket.close rescue StandardError
        thread.join
      end
    end
  end
end

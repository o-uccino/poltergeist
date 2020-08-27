# frozen_string_literal: true

require 'capybara/poltergeist/errors'
require 'capybara/poltergeist/command'
require 'json'
require 'time'

module Capybara::Poltergeist
  class Browser
    ERROR_MAPPINGS = {
      'Poltergeist.JavascriptError' => JavascriptError,
      'Poltergeist.FrameNotFound'   => FrameNotFound,
      'Poltergeist.InvalidSelector' => InvalidSelector,
      'Poltergeist.StatusFailError' => StatusFailError,
      'Poltergeist.NoSuchWindowError' => NoSuchWindowError,
      'Poltergeist.ScriptTimeoutError' => ScriptTimeoutError,
      'Poltergeist.UnsupportedFeature' => UnsupportedFeature,
      'Poltergeist.KeyError' => KeyError
    }.freeze

    attr_reader :server, :client, :logger

    def initialize(server, client, logger = nil)
      @server = server
      @client = client
      @logger = logger
    end

    def restart
      server.restart
      client.restart

      self.debug = @debug if defined?(@debug)
      self.js_errors = @js_errors if defined?(@js_errors)
      self.extensions = @extensions if @extensions
    end

    def visit(url)
      command 'visit', url
    end

    def current_url
      command 'current_url'
    end

    def frame_url
      command 'frame_url'
    end

    def status_code
      command 'status_code'
    end

    def body
      command 'body'
    end

    def source
      command 'source'
    end

    def title
      command 'title'
    end

    def frame_title
      command 'frame_title'
    end

    def parents(page_id, id)
      command 'parents', page_id, id
    end

    def find(method, selector)
      result = command('find', method, selector)
      result['ids'].map { |id| [result['page_id'], id] }
    end

    def find_within(page_id, id, method, selector)
      command 'find_within', page_id, id, method, selector
    end

    def all_text(page_id, id)
      command 'all_text', page_id, id
    end

    def visible_text(page_id, id)
      command 'visible_text', page_id, id
    end

    def delete_text(page_id, id)
      command 'delete_text', page_id, id
    end

    def property(page_id, id, name)
      command 'property', page_id, id, name.to_s
    end

    def attributes(page_id, id)
      command 'attributes', page_id, id
    end

    def attribute(page_id, id, name)
      command 'attribute', page_id, id, name.to_s
    end

    def value(page_id, id)
      command 'value', page_id, id
    end

    def set(page_id, id, value)
      command 'set', page_id, id, value
    end

    def select_file(page_id, id, value)
      command 'select_file', page_id, id, value
    end

    def tag_name(page_id, id)
      command('tag_name', page_id, id).downcase
    end

    def visible?(page_id, id)
      command 'visible', page_id, id
    end

    def clickable?(page_id, id)
      command 'clickable', page_id, id
    end

    def disabled?(page_id, id)
      command 'disabled', page_id, id
    end

    def click_coordinates(x, y)
      command 'click_coordinates', x, y
    end

    def evaluate(script, *args)
      command 'evaluate', script, *args
    end

    def evaluate_async(script, wait_time, *args)
      command 'evaluate_async', script, wait_time, *args
    end

    def execute(script, *args)
      command 'execute', script, *args
    end

    def within_frame(handle)
      if handle.is_a?(Capybara::Node::Base)
        command 'push_frame', [handle.native.page_id, handle.native.id]
      else
        command 'push_frame', handle
      end

      yield
    ensure
      command 'pop_frame'
    end

    def switch_to_frame(handle)
      case handle
      when Capybara::Node::Base
        command 'push_frame', [handle.native.page_id, handle.native.id]
      when :parent
        command 'pop_frame'
      when :top
        command 'pop_frame', true
      end
    end

    def window_handle
      command 'window_handle'
    end

    def window_handles
      command 'window_handles'
    end

    def switch_to_window(handle)
      command 'switch_to_window', handle
    end

    def open_new_window
      command 'open_new_window'
    end

    def close_window(handle)
      command 'close_window', handle
    end

    def find_window_handle(locator)
      return locator if window_handles.include? locator

      handle = command 'window_handle', locator
      raise NoSuchWindowError unless handle
      handle
    end

    def within_window(locator)
      original = window_handle
      handle = find_window_handle(locator)
      switch_to_window(handle)
      yield
    ensure
      switch_to_window(original)
    end

    def click(page_id, id, keys = [], offset = {})
      command 'click', page_id, id, keys, offset
    end

    def right_click(page_id, id, keys = [], offset = {})
      command 'right_click', page_id, id, keys, offset
    end

    def double_click(page_id, id, keys = [], offset = {})
      command 'double_click', page_id, id, keys, offset
    end

    def hover(page_id, id)
      command 'hover', page_id, id
    end

    def drag(page_id, id, other_id)
      command 'drag', page_id, id, other_id
    end

    def drag_by(page_id, id, x, y)
      command 'drag_by', page_id, id, x, y
    end

    def select(page_id, id, value)
      command 'select', page_id, id, value
    end

    def trigger(page_id, id, event)
      command 'trigger', page_id, id, event.to_s
    end

    def reset
      command 'reset'
    end

    def scroll_to(left, top)
      command 'scroll_to', left, top
    end

    def render(path, options = {})
      check_render_options!(options)
      options[:full] = !!options[:full]
      command 'render', path.to_s, options
    end

    def render_base64(format, options = {})
      check_render_options!(options)
      options[:full] = !!options[:full]
      command 'render_base64', format.to_s, options
    end

    def set_zoom_factor(zoom_factor)
      command 'set_zoom_factor', zoom_factor
    end

    def set_paper_size(size)
      command 'set_paper_size', size
    end

    def resize(width, height)
      command 'resize', width, height
    end

    def send_keys(page_id, id, keys)
      command 'send_keys', page_id, id, normalize_keys(Array(keys))
    end

    def path(page_id, id)
      command 'path', page_id, id
    end

    def network_traffic(type = nil)
      command('network_traffic', type).map do |event|
        NetworkTraffic::Request.new(
          event['request'],
          event['responseParts'].map { |response| NetworkTraffic::Response.new(response) },
          event['error'] ? NetworkTraffic::Error.new(event['error']) : nil
        )
      end
    end

    def clear_network_traffic
      command('clear_network_traffic')
    end

    def set_proxy(ip, port, type, user, password)
      args = [ip, port, type]
      args << user if user
      args << password if password
      command('set_proxy', *args)
    end

    def equals(page_id, id, other_id)
      command('equals', page_id, id, other_id)
    end

    def get_headers
      command 'get_headers'
    end

    def set_headers(headers)
      command 'set_headers', headers
    end

    def add_headers(headers)
      command 'add_headers', headers
    end

    def add_header(header, options = {})
      command 'add_header', header, options
    end

    def response_headers
      command 'response_headers'
    end

    def cookies
      Hash[command('cookies').map { |cookie| [cookie['name'], Cookie.new(cookie)] }]
    end

    def set_cookie(cookie)
      cookie[:expires] = cookie[:expires].to_i * 1000 if cookie[:expires]
      command 'set_cookie', cookie
    end

    def remove_cookie(name)
      command 'remove_cookie', name
    end

    def clear_cookies
      command 'clear_cookies'
    end

    def cookies_enabled=(flag)
      command 'cookies_enabled', !!flag
    end

    def set_http_auth(user, password)
      command 'set_http_auth', user, password
    end

    def js_errors=(val)
      @js_errors = val
      command 'set_js_errors', !!val
    end

    def page_settings=(settings)
      command 'set_page_settings', settings
    end

    def extensions=(names)
      @extensions = names
      Array(names).each do |name|
        command 'add_extension', name
      end
    end

    def url_whitelist=(whitelist)
      command 'set_url_whitelist', *whitelist
    end

    def url_blacklist=(blacklist)
      command 'set_url_blacklist', *blacklist
    end

    def debug=(val)
      @debug = val
      command 'set_debug', !!val
    end

    def clear_memory_cache
      command 'clear_memory_cache'
    end

    def command(name, *args)
      cmd = Command.new(name, *args)
      log cmd.message

      response = server.send(cmd)
      log response

      json = JSON.parse(response)

      if json['error']
        klass = ERROR_MAPPINGS[json['error']['name']] || BrowserError
        raise klass, json['error']
      else
        json['response']
      end
    rescue DeadClient
      restart
      raise
    end

    def go_back
      command 'go_back'
    end

    def go_forward
      command 'go_forward'
    end

    def refresh
      command 'refresh'
    end

    def accept_confirm
      command 'set_confirm_process', true
    end

    def dismiss_confirm
      command 'set_confirm_process', false
    end

    #
    # press "OK" with text (response) or default value
    #
    def accept_prompt(response)
      command 'set_prompt_response', response || false
    end

    #
    # press "Cancel"
    #
    def dismiss_prompt
      command 'set_prompt_response', nil
    end

    def modal_message
      command 'modal_message'
    end

    private

    def log(message)
      logger&.puts message
    end

    def check_render_options!(options)
      return unless options[:full] && options.key?(:selector)
      warn "Ignoring :selector in #render since :full => true was given at #{caller(1..1).first}"
      options.delete(:selector)
    end

    KEY_ALIASES = {
      command:   :Meta,
      equals:    :Equal,
      Control:   :Ctrl,
      control:   :Ctrl,
      multiply:  'numpad*',
      add:       'numpad+',
      divide:    'numpad/',
      subtract:  'numpad-',
      decimal:   'numpad.'
    }.freeze

    def combine_strings(keys)
      keys.chunk { |k| k.is_a? String }.map { |string, k| string ? [k.reduce(&:+)] : k }.reduce(&:+)
    end

    def is_modifier(key)
      return false unless %i[shift ctrl control alt meta command].include?(key.downcase)
      case key = key.to_s.downcase
      when 'control' then 'ctrl'
      when 'command' then 'meta'
      else key
      end
    end

    def key_descriptor(key)
      key = KEY_ALIASES.fetch(key, key)
      if (match = key.to_s.match(/numpad(.)/))
        { keys: match[1], modifier: 'keypad' }
      else
        key = key.to_s.split('_').map(&:capitalize).join if key !~ /^[A-Z]/
        { key: key }
      end
    end

    def normalize_keys(keys, pressed_keys = [], memo = [])
      case keys
      when Array
        pressed_keys.push []
        memo += combine_strings(keys).map { |k| normalize_keys(k, pressed_keys, memo) }
        pressed_keys.pop
        memo.flatten.compact
      when Symbol
        if (key_desc = is_modifier(keys))
          pressed_keys.last.push key_desc
          nil
        else
          # Return a known sequence for PhantomJS
          key = key_descriptor(keys)
          modifiers = Array(key[:modifier])
          modifiers.concat(pressed_keys.flatten)
          key[:modifier] = modifiers.join(',') unless modifiers.empty?
          key
        end
      when String
        modifiers = pressed_keys.flatten
        if modifiers.empty?
          keys # Plain string, nothing to do
        else
          { modifier: modifiers.join(','), keys: keys.upcase }
        end
      end
    end
  end
end

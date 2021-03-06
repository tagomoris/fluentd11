#
# Fluentd
#
# Copyright (C) 2011-2013 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module Fluentd
  module Config

    class Parser < LiteralParser
      def initialize(strscan, include_basepath, fname, eval_context)
        super(strscan)
        @include_basepath = include_basepath
        @fname = fname
        @eval_context = eval_context
      end

      SPACING_LINE_END = /[ \t]*(?:\;|[\r\n]|\z|\#.*?(?:\z|[\r\n]))+/

      #SIMPLE_STRING = /(?:(?!#{SPACING_LINE_END}).)*/

      MATCH_PATTERN_STRING_CHARSET = /[^\<\>]/

      def_symbol :k_lpoint, "<"
      def_symbol :k_rpoint, ">"
      def_symbol :k_tag_end, "</"

      def_keyword :k_include, '@include'

      def self.read(path, eval_context=Object.new)
        path = File.expand_path(path)
        data = File.read(path)
        parse(data, File.basename(path), File.dirname(path), eval_context)
      end

      def self.parse(data, fname, basepath=Dir.pwd, eval_context=Object.new)
        ss = StringScanner.new(data)
        ps = Parser.new(ss, basepath, fname, eval_context)
        ps.parse!
      end

      def parse!
        attrs, elems = parse_element(true, nil)
        root = Element.new('ROOT', '', attrs, elems)

        spacing
        unless eof?
          parse_error! "expected EOF"
        end

        return root
      end

      def parse_element(allow_include, elem_name, attrs={}, elems=[])
        while true
          spacing
          break if eof?

          if k_tag_end  # </
            # end tag
            name = parse_string
            unless k_rpoint
              parse_error! "expected >"
            end
            if name != elem_name
              parse_error! "unmatched end tag"
            end
            break

          elsif k_lpoint  # <
            # start nested tag
            e_name = parse_string
            unless k_rpoint
              # <name string
              skip(/[ \t]*/)
              e_arg = parse_match_pattern_string
              unless k_rpoint
                parse_error! "expected >"
              end
            end
            e_arg ||= ''  # FIXME nil?
            e_attrs, e_elems = parse_element(false, e_name)
            elems << Element.new(e_name, e_arg, e_attrs, e_elems)

          elsif allow_include && k_include  # @include
            eval_include(attrs, elems, value)

          else
            # attribute key-value
            k = parse_map_key_string
            skip(/[ \t]+/)
            if skip(SPACING_LINE_END)
              v = nil
            else
              v = parse_literal
              unless skip(SPACING_LINE_END)
                parse_error! "expected \\n or ';'"
              end
            end
            #elsif skip(/[ \t]+/)
            #  # backward compatibility?
            #  v = parse_string_line

            attrs[k] = v
          end
        end

        return attrs, elems
      end

      #def parse_string_line
      #  s = @ss.scan(SIMPLE_STRING) || ''
      #  return s.rstrip
      #end

      def parse_match_pattern_string
        spacing

        if string = try_parse_quoted_string
          return string
        end

        string = try_parse_special_string(MATCH_PATTERN_STRING_CHARSET)
        unless string
          parse_error! "expected match pattern or pattern surrounded by '\"'"
        end

        return string
      end

      def eval_include(attrs, elems, uri)
        u = URI.parse(uri)
        if u.scheme == 'file' || u.path == uri  # file path
          path = u.path
          if path[0] != ?/
            pattern = File.expand_path("#{@include_basepath}/#{path}")
          else
            pattern = path
          end

          Dir.glob(pattern).each {|path|
            basepath = File.dirname(path)
            fname = File.basename(path)
            data = File.read(path)
            ss = StringScanner.new(data)
            Parser.new(ss, basepath, fname, @eval_context).parse(true, nil, attrs, elems)
          }

        else
          basepath = '/'
          fname = path
          require 'open-uri'
          data = nil
          open(uri) {|f| read = f.read }
          ss = StringScanner.new(data)
          Parser.new(ss, basepath, fname, @eval_context).parse(true, nil, attrs, elems)
        end

      rescue SystemCallError
        e = ConfigParseError.new("include error #{uri}")
        e.set_backtrace($!.backtrace)
        raise e
      end

      # override
      def eval_embedded_code(code)
        @eval_context.instance_eval(code)
      end

      # override
      def error_sample
        "#{@fname} #{super}"
      end
    end

  end
end

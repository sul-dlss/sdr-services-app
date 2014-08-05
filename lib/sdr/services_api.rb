require 'moab_stanford'
require 'druid-tools'
require 'sys/filesystem'
require "sinatra/reloader"
require 'sinatra/advanced_routes'

module Sdr
  class ServicesApi < Sinatra::Base

    # Register extensions
    register Sinatra::AdvancedRoutes
    configure :development do
      register Sinatra::Reloader
    end

    # See Sinatra-error-handling for explanation of exception behavior
    configure do
      enable :logging
      disable :raise_errors
      disable :show_exceptions
    end

    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      [username, password] == [SdrServices::Config.username, SdrServices::Config.password]
    end

    helpers do
      def latest_version
        unless @latest_version
          @latest_version = Stanford::StorageServices.current_version(params[:druid])
        end
        @latest_version
      end

      def caption(version)
        "Object = #{params[:druid]} - Version = #{version ? version.to_s : latest_version} of #{latest_version}"
      end

      def subset_param()
        (params[:subset].nil? || params[:subset].strip.empty?) ? 'all' : params[:subset]
      end

      def version_param()
        (params[:version].nil? || params[:version].strip.empty?) ? nil : params[:version].to_i
      end

      def file_id_param()
        # request.path_info.  split('/')[5..-1].join('/')
        params[:splat].first
      end

      def signature_param()
        if (params[:signature].nil? || params[:signature].strip.empty?)
          nil
        elsif params[:signature].split(',').size > 1
          values = params[:signature].split(',')
          signature = FileSignature.new(:size=>values[0])
          values[1..-1].each do |checksum|
            case checksum.size
              when 32
                signature.md5 = checksum
              when 40
                signature.sha1 = checksum
              when 64
                signature.sha256 = checksum
            end
          end
          signature
        else
          nil
        end
      end

      def retrieve_file(druid, category, file_id, version, signature)
        if file_id == []
          [400, "file id not specified"]
        else
          if not signature.nil?
            content_file = Stanford::StorageServices.retrieve_file_using_signature(category, signature , druid, version)
          else
            content_file = Stanford::StorageServices.retrieve_file(category, file_id, druid, version)
          end
          # [200, {'content-type' => 'application/octet-stream'}, content_file.read]
          send_file content_file, {:disposition => :attachment , :filename => Pathname(file_id).basename }
        end
      end

      def file_list(druid, category, version)
        ul = Array.new
        file_group = Stanford::StorageServices.retrieve_file_group(category, druid, version)
        file_group.path_hash.each do |file_id,signature|
          vopt = version ? "?version=#{version}" : ""
          if category =~ /manifest/
            href = url("/objects/#{druid}/#{category}/#{file_id}#{vopt}")
          else
            signature_value = "#{signature.size.to_s},#{signature.checksums.values[0]}"
            href = url("/objects/#{druid}/#{category}/#{file_id}?signature=#{signature_value}")
          end
          ul << "<li><a href='#{href}'>#{file_id}</a></li>"
        end
        title = "<title>#{caption(version)} - #{category.capitalize}</title>\n"
        h3 = "<h3>#{caption(version)} - #{category.capitalize}</h3>\n"
        list = "<ul>\n#{ul.join("\n")}\n</ul>\n"
        "<html><head>\n#{title}</head><body>\n#{h3}#{list}</body></html>\n"
      end

      def menu(druid, version)
        vopt = version ? "?version=#{version}" : ""
        ul = Array.new
        href = url("/objects/#{druid}/list/content#{vopt}")
        ul << "<li><a href='#{href}'>get content list</a></li>"
        href = url("/objects/#{druid}/list/metadata#{vopt}")
        ul << "<li><a href='#{href}'>get metadata list</a></li>"
        href = url("/objects/#{druid}/list/manifests#{vopt}")
        ul << "<li><a href='#{href}'>get manifest list</a></li>"
        href = url("/objects/#{druid}/version_list")
        ul << "<li><a href='#{href}'>get version list</a></li>"

        title = "<title>#{caption(version)}</title>\n"
        h3 = "<h3>#{caption(version)}</h3>\n"
        list = "<ul>\n#{ul.join("\n")}\n</ul>\n"
        "<html><head>\n#{title}</head><body>\n#{h3}#{list}</body></html>\n"
      end

      def version_list
        ul = Array.new
        version_metadata_file = Stanford::StorageServices.version_metadata(params[:druid])
        vm = Moab::VersionMetadata.parse(version_metadata_file.read)
        vm.versions.each do |v|
          v.inspect
          href = url("/objects/#{params[:druid]}?version=#{v.version_id.to_s}")
          ul << "<li><a href='#{href}'>Version #{v.version_id.to_s} - #{v.description}</a></li>"
        end
        title = "<title>Object = #{params[:druid]} - Versions</title>\n"
        h3 = "<h3>Object = #{params[:druid]} - Versions</h3>\n"
        list = "<ul>\n#{ul.join("\n")}\n</ul>\n"
        "<html><head>\n#{title}</head><body>\n#{h3}#{list}</body></html>\n"
      end

      def route_yard_name(route)
        # this method is called in lib/sdr/views/documentation.haml
        # it assumes the @method annotations below follow a uniform pattern
        # to generate links from /documentation into YARD documentation, which is
        # served from /doc (actually generated by yard into lib/sdr/public; see 'rake doc')
        if route.path == '/'
           return 'get_root'
        else
           return route.verb.downcase + route.path.gsub('/','_').gsub(':','').gsub('_*','')
        end
      end

    end

    error Moab::ObjectNotFoundException do
      [404, request.env['sinatra.error'].message]
    end

    error Moab::FileNotFoundException do
      [404, request.env['sinatra.error'].message]
    end

    error Moab::InvalidMetadataException do
      [400, "Bad Request: Invalid contentMetadata - " + request.env['sinatra.error'].message]
    end

    error do
      errmsg = 'Unexpected Error: ' + request.env['sinatra.error'].message
      logger.error errmsg
      [500, errmsg]
    end



    # @macro [attach] sinatra.get
    #   @overload get "$1"
    # @method get_root
    # Redirects to /documentation
    get '/' do
      redirect to('/documentation')
    end

    # @method get_doc
    # REST API details
    get '/doc' do
      send_file File.join(settings.public_folder, '/Sdr/ServicesApi.html')
    end

    # @method get_documentation
    # REST API documentation
    get '/documentation' do
      haml :'documentation'
    end

    # @method get_error_test_file_not_found
    # Raises Moab::FileNotFoundException
    get '/error_test/file_not_found' do
      raise Moab::FileNotFoundException
    end

    # @method get_error_test_invalid_metadata
    # Raises Moab::InvalidMetadataException
    get '/error_test/invalid_metadata' do
      raise Moab::InvalidMetadataException
    end

    # @method get_error_test_object_not_found
    # Raises Moab::ObjectNotFoundException
    get '/error_test/object_not_found' do
      raise Moab::ObjectNotFoundException
    end

    # @method get_objects
    # Placeholder to test logging (does not return a list of objects)
    get '/objects' do
      # TODO add exception logging
      logger.info 'logging is working'
      "ok\n"
    end

    # @method get_objects_druid
    # @param [String] druid DRUID-ID
    # @param [int] version DRUID-version
    # Displays DRUID links menu (html)
    get '/objects/:druid' do
      [200, {'content-type' => 'text/html'}, menu(params[:druid], version_param)]
    end

    # @method get_objects_druid_current_version
    # @param [String] druid DRUID-ID
    # @return [String] DRUID current version (xml)
    get '/objects/:druid/current_version' do
      current_version = Stanford::StorageServices.current_version(params[:druid])
      [200, {'content-type' => 'application/xml'}, "<currentVersion>#{current_version.to_s}</currentVersion>"]
    end

    # @method get_objects_druid_version_metadata
    # @param [String] druid DRUID-ID
    # @return [String] DRUID version metadata (xml)
    get '/objects/:druid/version_metadata' do
      version_metadata = Stanford::StorageServices.version_metadata(params[:druid])
      [200, {'content-type' => 'application/xml'}, version_metadata.read]
    end

    # @method get_objects_druid_version_list
    # @param [String] druid DRUID-ID
    # @return [String] DRUID version list (html)
    get '/objects/:druid/version_list' do
      [200, {'content-type' => 'text/html'}, version_list]
    end

    # @method get_objects_druid_version_differences
    # @param [String] druid DRUID-ID
    # @param [String] base DRUID-base-version
    # @param [String] compare DRUID-compare-version
    # @return [String] DRUID version diffs (xml)
    get '/objects/:druid/version_differences' do
      version_differences = Stanford::StorageServices.version_differences(params[:druid], params[:base].to_i, params[:compare].to_i)
      [200, {'content-type' => 'application/xml'}, version_differences.to_xml]
    end

    # @method get_objects_druid_list_category
    # @param [String] druid DRUID-ID
    # @param [String] category DRUID-category
    # @param [int] version DRUID-version
    # @return [String] DRUID version diffs
    get '/objects/:druid/list/:category' do
      [200, {'content-type' => 'text/html'}, file_list( params[:druid], params[:category], version_param)]
    end

    # @method get_objects_druid_content
    # @param [String] druid DRUID-ID
    # @param [String] file DRUID file ID
    # @param [int] version DRUID version number
    # @param [String] signature DRUID file signature (e.g. md5 hash)
    # @return DRUID file content
    get '/objects/:druid/content/*' do
      retrieve_file(params[:druid],'content',file_id_param, version_param, signature_param)
    end

    # @method get_objects_druid_metadata
    # @param [String] druid DRUID-ID
    # @param [String] file DRUID metadata file ID
    # @param [int] version DRUID version number
    # @param [String] signature DRUID file signature (e.g. md5 hash)
    # @return DRUID metadata file
    get '/objects/:druid/metadata/*' do
      retrieve_file(params[:druid],'metadata',file_id_param, version_param, signature_param)
    end

    # @method get_objects_druid_manifest
    # @param [String] druid DRUID-ID
    # @param [String] file DRUID manifest file ID
    # @param [int] version DRUID version number
    # @param [String] signature DRUID file signature (e.g. md5 hash)
    # @return DRUID manifest file
    get '/objects/:druid/manifest/*' do
      retrieve_file(params[:druid],'manifest',file_id_param, version_param, signature_param)
    end

    # @method get_objects_druid_manifests
    # @param [String] druid DRUID-ID
    # @param [String] file DRUID manifest file ID
    # @param [int] version DRUID version number
    # @param [String] signature DRUID file signature (e.g. md5 hash)
    # @return DRUID manifest file
    get '/objects/:druid/manifests/*' do
      retrieve_file(params[:druid],'manifest',file_id_param, version_param, signature_param)
    end

    # @method get_objects_druid_cm-remediate
    # @param [String] druid DRUID-ID
    # @param [int] version DRUID version number
    # @return [String] Returns a remediated copy of the contentMetadata with fixity data filled in
    get '/objects/:druid/cm-remediate' do
      remediated_cm = Stanford::StorageServices.cm_remediate(params[:druid], version_param)
      [200, {'content-type' => 'application/xml'}, remediated_cm]
    end

    # @method get_objects_druid_transfer
    # @param [String] druid DRUID-ID
    # @return [String] An rsync command that transfers the DRUID tree to a configured destination.
    get '/objects/:druid/transfer' do
      request.body.rewind
      source_path = Stanford::StorageServices.object_path(params[:druid])
      destination_host = SdrServices::Config.rsync_destination_host
      destination_path = SdrServices::Config.rsync_destination_path
      destination_path = File.join(destination_path,params[:druid].split(/:/).last)
      if destination_host.nil? or destination_host.empty?
        # local copy (for testing purposes)
        # create all directories in the destination path
        `mkdir -p #{destination_path}`
        # note the trailing spaces to avoid creating already existing subdir at the destination
        rsync_cmd = "rsync -a '#{source_path}/' '#{destination_path}/'"
      else
        `ssh #{destination_host} 'mkdir -p #{destination_path}'`
        rsync_cmd = "rsync -a -e ssh '#{source_path}/' '#{destination_host}:#{destination_path}/'"
      end
      # use at command to allow immediate response to caller
      `echo "#{rsync_cmd}" | at now`
      [200, "#{rsync_cmd}\n" ]
    end

    # @method get_gb_used
    # @return [Integer] The Gb used on SDR storage file systems
    get '/gb_used' do
      gigabye_size = 1024*1024*1024
      storage_mounts = Sys::Filesystem.mounts.select{|mount| SdrServices::Config.storage_filesystems.include?(mount.mount_point) }
      storage_stats = storage_mounts.map{|mount| Sys::Filesystem.stat(mount.mount_point)}
      used = storage_stats.inject(0){|sum,stat| sum + ((stat.blocks.to_f-stat.blocks_available.to_f) *stat.block_size.to_f)/gigabye_size }
      [200, used.round.to_s ]
    end

    # @method get_test_file_id_param
    get '/test/file_id_param/*' do
      file_id_param
    end


    # @macro [attach] sinatra.post
    #   @overload post "$1"
    # @method post_objects_druid_cm-adds
    # @param [String] new_content_metadata The POST body should contain content metadata (xml) to be compared to the base
    # @param [String] druid DRUID-ID
    # @param [String] subset Specifies which subset of files to list in the inventories extracted from the contentMetadata (all|preserve|publish|shelve)
    # @param [Integer] base_version The ID of the version whose inventory is the basis of, if nil use latest version
    # @return [String] an XML report of differences between the content metadata and the specified version
    post '/objects/:druid/cm-adds' do
      request.body.rewind
      cmd_xml = request.body.read
      additions = Stanford::StorageServices.cm_version_additions(cmd_xml, params[:druid], version_param())
      [200, {'content-type' => 'application/xml'}, additions.to_xml]
    end

    # @method post_objects_druid_cm-inv-diff
    # @param [String] new_content_metadata The POST body should contain content metadata (xml) to be compared to the base
    # @param [String] druid DRUID-ID
    # @param [String] subset Specifies which subset of files to list in the inventories extracted from the contentMetadata (all|preserve|publish|shelve)
    # @param [Integer] base_version The ID of the version whose inventory is the basis of, if nil use latest version
    # @return [String] an XML report of differences between the content metadata and the specified version
    post '/objects/:druid/cm-inv-diff' do
      # Both technical-metadata and shelve robots currently make a call to Dor::Itemizable#get_content_diff which:
      # 1. pulls new contentMetadata from Fedora
      # 2. posts that contentMetadata to sdr-service's  cm-inv-diff
      # 3. receives a fileInventoryDifferences report in response
      request.body.rewind
      cmd_xml = request.body.read
      diff = Stanford::StorageServices.compare_cm_to_version(cmd_xml, params[:druid], subset_param(), version_param())
      [200, {'content-type' => 'application/xml'}, diff.to_xml]
    end

    # Adopting POST to avoid URI length restrictions on GET, in cases where a DRUID array could be very long.

    # @method post_objects_transfer
    # @param [String] druids a comma separated list of DRUID-ID
    # @param [String] destination_host a <user>@<hostname> where <user> is authorized to ssh into <hostname>
    # @param [String] destination_path an absolute path that <user> can create/write into on <hostname>
    # @param [String] destination_type a path suffix (druid-id | druid-tree-short | druid-tree-long)
    # @return [String] a success or failure message
    post '/objects/transfer' do
      # Parse the params to construct CLI args for the ./bin/druid_transfer.rb script
      destination_host = params[:destination_host]
      destination_path = params[:destination_path]
      return [400, "Invalid parameters: " + JSON.dump(params)] if destination_host.nil? || destination_path.nil?
      destination_type = params[:destination_type] || Moab::Config.path_method
      druids = params[:druids].split(',').uniq
      script_file = File.expand_path(File.dirname(__FILE__) + '../../../bin/druid_transfer.rb')
      # Check this is the correct script file.
      return [500, 'Failed to locate druid_transfer script correctly.'] unless File.exists? script_file
      script_args = "-h '#{destination_host}' -p '#{destination_path}' -t '#{destination_type}' -d #{druids.join(',')}"
      success = system("#{script_file} #{script_args}")
      return [500, "Failed to initiate druid_transfer script.\n"] unless success
      return [200, "Scheduled DRUID transfers; details are emailed to SDR managers.\n"]
      # Note on how to test this with curl:
      # Start the server with 'rackup' (maybe comment out the STDIN/STDOUT redirection in config.ru), then issue:
      # curl -X POST --user "devUser:devPass" --data "destination_host=localhost&destination_path='/tmp'&druids=druid:jq937jp0017" http://localhost:9292/objects/transfer
    end



    def self.new(*)
      super
    end


  end

end

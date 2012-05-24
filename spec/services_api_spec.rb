require 'spec_helper'

describe Sdr::ServicesApi do
  
  def app
    @app ||= Sdr::ServicesApi
  end

  describe "POST '/sdr/objects/{druid}/cm-inv-diff'" do
    let(:content_md) { <<-EOXML
      <?xml version="1.0"?>
      <contentMetadata type="sample" objectId="druid:jq937jp0017">
        <resource type="version" sequence="1" id="version-2">
          <file datetime="2012-03-26T08:15:11-06:00" size="40873" id="title.jpg">
            <checksum type="MD5">1a726cd7963bd6d3ceb10a8c353ec166</checksum>
            <checksum type="SHA-1">583220e0572640abcd3ddd97393d224e8053a6ad</checksum>
          </file>
          <file datetime="2012-03-26T09:35:15-06:00" size="32915" id="page-1.jpg">
            <checksum type="MD5">c1c34634e2f18a354cd3e3e1574c3194</checksum>
            <checksum type="SHA-1">0616a0bd7927328c364b2ea0b4a79c507ce915ed</checksum>
          </file>
          <file datetime="2012-03-26T09:23:36-06:00" size="39450" id="page-2.jpg">
            <checksum type="MD5">82fc107c88446a3119a51a8663d1e955</checksum>
            <checksum type="SHA-1">d0857baa307a2e9efff42467b5abd4e1cf40fcd5</checksum>
          </file>
          <file datetime="2012-03-26T09:24:39-06:00" size="19125" id="page-3.jpg">
            <checksum type="MD5">a5099878de7e2e064432d6df44ca8827</checksum>
            <checksum type="SHA-1">c0ccac433cf02a6cee89c14f9ba6072a184447a2</checksum>
          </file>
        </resource>
      </contentMetadata>
      EOXML
    }
    
    it "returns diff xml between content metadata and a specific version" do
      post '/sdr/objects/druid:jq937jp0017/cm-inv-diff?version=1', content_md
      last_response.should be_ok
      last_response.body.should =~ /<fileInventoryDifference/
    end
    
    it "returns versionAdditions xml between content metadata and a specific version" do
      post '/sdr/objects/druid:jq937jp0017/cm-adds?version=3', content_md
      last_response.should be_ok
      last_response.body.should =~ /<fileInventory type="additions"/
    end

    it "handles version as an optional paramater" do
      post '/sdr/objects/druid:jq937jp0017/cm-inv-diff', content_md
      last_response.should be_ok
      last_response.body.should =~ /<fileInventoryDifference/
    end

    it "returns current version number" do
      get '/sdr/objects/druid:jq937jp0017/current_version'
      last_response.should be_ok
      last_response.body.should == '<currentVersion>3</currentVersion>'
    end

    it "returns current version metadata" do
      get '/sdr/objects/druid:jq937jp0017/version_metadata'
      last_response.should be_ok
      last_response.body.should =~ /<versionMetadata objectId="druid:ab123cd4567">/
    end

    it "returns a version differences report" do
      get '/sdr/objects/druid:jq937jp0017/version_differences?base=1&compare=3'
      last_response.should be_ok
      last_response.body.should =~ /<fileInventoryDifference objectId="druid:jq937jp0017"/
    end

    it "returns a content file" do
      get '/sdr/objects/druid:jq937jp0017/content/title.jpg?version=1'
      last_response.should be_ok
      last_response.header["content-type"].should =~ /application\/octet-stream/
    end

    it "returns a content file signature" do
      get '/sdr/objects/druid:jq937jp0017/content/title.jpg?signature=true'
      last_response.should be_ok
      last_response.header["content-type"].should =~ /application\/xml/
      last_response.body.should =~ /<fileSignature size="40873" md5="1a726cd7963bd6d3ceb10a8c353ec166" sha1="583220e0572640abcd3ddd97393d224e8053a6ad"\/>/
    end

    it "returns a metadata file" do
      get '/sdr/objects/druid:jq937jp0017/metadata/provenanceMetadata.xml'
      last_response.should be_ok
      last_response.body.should =~ /<provenanceMetadata/
    end

    it "returns a metadata file signature" do
       get '/sdr/objects/druid:jq937jp0017/metadata/provenanceMetadata.xml?signature'
       last_response.should be_ok
       last_response.body.should =~ /<fileSignature size="564" md5="17071e4607de4b272f3f06ec76be4c4a" sha1="b796a0b569bde53953ba0835bb47f4009f654349"\/>/
     end

    it "returns the most recent manifest file if version param is omitted" do
      get '/sdr/objects/druid:jq937jp0017/manifest/signatureCatalog.xml'
      last_response.should be_ok
      last_response.body.should =~ /<signatureCatalog objectId="druid:jq937jp0017" versionId="3"/
    end

    it "returns a manifest file signature" do
      get '/sdr/objects/druid:jq937jp0017/manifest/signatureCatalog.xml?signature'
      last_response.should be_ok
      last_response.body.should =~ /<fileSignature size="4210" md5="a4b5e6f14bcf0fd5f8e295c0001b6f19" sha1="e9804e90bf742b2f0c05858e7d37653552433183"\/>/
    end

  end
end

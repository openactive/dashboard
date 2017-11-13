require 'datasets_cache'

describe DatasetsCache do

  describe ".update" do
    it "it stores result of request" do
      expect(DatasetsCache.update).to eql("OK")
    end
  end

  describe ".all" do
    it "retrieves a collection of datasets" do
      datasets = DatasetsCache.all
      expect(datasets.class).to eql(Array)
      expect(datasets.size).to be > 0
      expect(datasets[0].class).to eql(Hash)
      expect(datasets[0].keys).to include("id", "title", "data_url") 
    end
  end

end
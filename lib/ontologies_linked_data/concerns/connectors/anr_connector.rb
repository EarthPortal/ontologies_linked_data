require_relative 'base_connector'

module Connectors
  class AnrConnector < BaseConnector
    DATASET_MAPPINGS = {
      'ods_france2030-projets' => {
        acronym: 'acronyme',
        name: 'action_nom',
        description: 'resume',
        homepage: 'lien',
        grant_number: 'eotp_projet',
        start_date: 'date_debut_projet',
        end_date: 'date_fin',
        region: 'region_du_projet',
        year: 'annee_de_contractualisation'
      },
      'aapg-projets' => {
        acronym: 'acronyme_projet',
        name: 'intitule_complet_du_comite',
        description: nil,
        homepage: 'lien',
        grant_number: 'code_projet_anr',
        start_date: nil,
        end_date: nil,
        region: 'libelle_de_region_tutelle_hebergeante',
        year: 'edition'
      }
    }.freeze

    ANR_FUNDER = {
      type: 'Agent',
      name: "Agence Nationale de la Recherche",
      homepage: "https://anr.fr"
    }.freeze

    private
    def build_url
      dataset_id = params[:dataset_id]
      raise ConnectorError, "Dataset ID is required" unless dataset_id
      "https://dataanr.opendatasoft.com/api/explore/v2.1/catalog/datasets/#{dataset_id}/records"
    end

    def build_params(params)
      raise ConnectorError, "Query parameter is required" unless params[:query]
      {
        limit: params[:limit] || 20,
        where: build_query_conditions(params)
      }
    end

    def build_query_conditions(params)
      mapping = get_dataset_mapping      
      if params[:query]
        query_term = params[:query]
        acronym_field = mapping[:acronym]
        grant_field = mapping[:grant_number]
        "(#{acronym_field} LIKE '*#{query_term}*' OR #{grant_field} LIKE '*#{query_term}*')"
      else
        raise ConnectorError, "Query parameter is required"
      end
    end
    
    def map_response(data)
      raise ConnectorError, "No projects found matching search criteria" if data['results'].empty?      
      mapping = get_dataset_mapping
      data['results'].map { |result| build_project_data(result, mapping) }     
    end

    def get_dataset_mapping
      mapping = DATASET_MAPPINGS[params[:dataset_id]]
      raise ConnectorError, "Unsupported dataset: #{params[:dataset_id]}" unless mapping
      mapping
    end

    def find_matching_project(results, mapping)
      if params[:id]
        results.find { |r| r[mapping[:grant_number]] == params[:id] }
      elsif params[:acronym]
        results.find { |r| r[mapping[:acronym]] == params[:acronym] }
      end
    end

    def build_project_data(result, mapping)
      {
        source: 'ANR',
        type: 'FundedProject',
        acronym: result[mapping[:acronym]],
        name: result[mapping[:name]],
        description: get_description(result, mapping),
        homepage: result[mapping[:homepage]],
        ontologyUsed: [],
        creator: nil,
        created: DateTime.now,
        updated: DateTime.now,
        keywords: [],
        contact: nil,
        institution: nil,
        coordinator: nil,
        logo: nil,
        grant_number: result[mapping[:grant_number]],
        start_date: result[mapping[:start_date]],
        end_date: result[mapping[:end_date]],
        funder: ANR_FUNDER
      }
    end

    def get_description(result, mapping)
      if params[:dataset_id] == 'ods_france2030-projets'
        result[mapping[:description]] || result['action_nom_long']
      else
        nil
      end
    end
  end
end
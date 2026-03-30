const fs = require('fs');
const readline = require('readline');

async function cleanSchema(inputFile, outputFile) {
    const fileStream = fs.createReadStream(inputFile);

    const rl = readline.createInterface({
        input: fileStream,
        crlfDelay: Infinity
    });

    const outStream = fs.createWriteStream(outputFile);
    
    let skipBlock = false;

    for await (let line of rl) {
        // 1. Skip Supabase specific system statements
        if (line.match(/^CREATE SCHEMA (IF NOT EXISTS )?public/)) {
            continue;
        }
        if (line.match(/^ALTER SCHEMA public OWNER TO /)) {
            continue;
        }
        if (line.match(/^COMMENT ON SCHEMA public IS/)) {
            continue;
        }

        // 2. Skip OWNER TO statements (Supabase admin/postgres permissions usually block this)
        if (line.match(/^ALTER .* OWNER TO .*/)) {
            continue;
        }

        // 3. Make Functions safe to recreate (Updates existing functions)
        if (line.match(/^CREATE FUNCTION /)) {
            line = line.replace(/^CREATE FUNCTION /, 'CREATE OR REPLACE FUNCTION ');
        }

        // 4. Make Views safe to recreate
        if (line.match(/^CREATE VIEW /)) {
            line = line.replace(/^CREATE VIEW /, 'CREATE OR REPLACE VIEW ');
        }
        
        // 5. Triggers: We can leave them as is, but if they exist, it might fail. 
        // Postgres 14+ supports CREATE OR REPLACE TRIGGER. Supabase is 15+.
        if (line.match(/^CREATE TRIGGER /)) {
            line = line.replace(/^CREATE TRIGGER /, 'CREATE OR REPLACE TRIGGER ');
        }

        // Write cleaned line to output
        outStream.write(line + '\n');
    }

    console.log(`Cleaned schema saved to ${outputFile}`);
}

cleanSchema('schema.sql', 'schema_clean.sql');
